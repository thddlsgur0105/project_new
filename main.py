import uvicorn
from fastapi import FastAPI, HTTPException
from pydantic import BaseModel, Field # Field 임포트
from typing import Dict, List, Optional
from datetime import datetime
from fastapi.middleware.cors import CORSMiddleware

from fastapi import WebSocket, WebSocketDisconnect, Depends
from database import SessionLocal, engine
from sqlalchemy.orm import Session
from fastapi.responses import HTMLResponse

from models import User, Base

Base.metadata.create_all(bind=engine)

# ----------------- FastAPI 앱 설정 -----------------
app = FastAPI()

def get_db():
    db = SessionLocal()
    try:
        yield db
    finally:
        db.close()

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# ----------------- 데이터 모델 정의 -----------------
class Study(BaseModel):
    # Flutter Study 모델에 맞춰 필드명과 타입 변경
    # Flutter의 index 필드에 대응 (nullable로 정의)
    index: Optional[int] = Field(None, alias="study_index") # study_index를 실제 JSON 키로 사용
    title: str
    description: str # Flutter의 description에 맞춰 변경 (FastAPI의 'desc' 역할)
    descriptionMore: str = Field(..., alias="description_more") # Flutter의 descriptionMore에 맞춰 추가 (FastAPI의 'content' 역할)
    author: str
    comments: List[Dict] = []
    # members_study_time 필드는 현재 Flutter Study 모델에 없으므로, 필요 없으면 제거하거나,
    # 만약 Flutter에서도 사용해야 한다면 Flutter Study 모델에도 추가해야 합니다.
    # members_study_time: Dict[str, int] = {}


class Comment(BaseModel):
    author: str
    text: str
    time: str

class SignupData(BaseModel):
    email: str
    password: str
    name: str

class LoginData(BaseModel):
    email: str
    password: str

class StudyTimeUpdate(BaseModel):
    userName: str
    duration_minutes: int

class JoinStudyRequest(BaseModel):
    username: str
    study_index: int # 백엔드는 여전히 study_index를 받을 것임

# ----------------- 임시 데이터베이스 -----------------
users_db: Dict[str, Dict] = {}

# Flutter Study 모델의 필드명에 맞게 key 이름을 변경합니다.
# "studyIndex" -> "study_index"
# "desc" -> "description"
# "content" -> "description_more"
study_list: List[Dict] = [
    # {
    #     "study_index": 0, # 변경: studyIndex -> study_index
    #     "title": "TOEIC 스터디",
    #     "description": "토익 900점을 목표로 하는 스터디입니다.", # 변경: desc -> description
    #     "description_more": "매일 단어 50개 암기 및 LC 1세트 풀기", # 변경: content -> description_more
    #     "time": "2024-07-12T10:00:00Z", # Flutter Study 모델에 없으므로 필요 없다면 제거 가능
    #     "comments": [],
    #     "author": "김토익",
    #     "members_study_time": { # Flutter Study 모델에 없으므로 필요 없다면 제거 가능
    #         "김토익": 150,
    #         "이리스닝": 80,
    #         "박단어": 200,
    #     }
    # },
    # {
    #     "study_index": 1, # 변경: studyIndex -> study_index
    #     "title": "일본어 스터디",
    #     "description": "JLPT N2를 목표로 하는 스터디입니다.", # 변경: desc -> description
    #     "description_more": "매주 문법 2챕터 및 한자 20개 암기", # 변경: content -> description_more
    #     "time": "2024-07-12T11:00:00Z", # Flutter Study 모델에 없으므로 필요 없다면 제거 가능
    #     "comments": [],
    #     "author": "최히라",
    #     "members_study_time": { # Flutter Study 모델에 없으므로 필요 없다면 제거 가능
    #         "최히라": 50,
    #         "정가나": 120,
    #         "윤한자": 75,
    #     }
    # }
]

chat_rooms: Dict[int, List[WebSocket]] = {}  # study_index별로 소켓 리스트
chat_logs: Dict[int, List[str]] = {}

# ----------------- API 엔드포인트 -----------------

@app.websocket("/ws/chat/{study_index}")
async def chat_websocket(websocket: WebSocket, study_index: int):
    await websocket.accept()

    if study_index not in chat_rooms:
        chat_rooms[study_index] = []
    if study_index not in chat_logs:
        chat_logs[study_index] = []

    chat_rooms[study_index].append(websocket)

    try:
        while True:
            data = await websocket.receive_text()
            chat_logs[study_index].append(data)  # ✅ 채팅 로그 저장
            for connection in chat_rooms[study_index]:
                await connection.send_text(data)
    except WebSocketDisconnect:
        chat_rooms[study_index].remove(websocket)

@app.get("/chat/{study_index}/logs")
def get_chat_logs(study_index: int):
    return {"logs": chat_logs.get(study_index, [])}

@app.post("/signup")
def signup(data: SignupData, db: Session = Depends(get_db)):
    existing_user = db.query(User).filter(User.email == data.email).first()
    if existing_user:
        raise HTTPException(status_code=400, detail="이미 등록된 이메일입니다.")

    new_user = User(email=data.email, password=data.password, name=data.name)
    db.add(new_user)
    db.commit()
    db.refresh(new_user)

    return {"message": "회원가입 성공!"}

@app.post("/login")
def login(data: LoginData, db: Session = Depends(get_db)):
    user = db.query(User).filter(User.email == data.email).first()
    if not user or user.password != data.password:
        raise HTTPException(status_code=401, detail="이메일 또는 비밀번호가 일치하지 않습니다.")
    return {"message": "로그인 성공", "name": user.name, "email": user.email}

@app.post("/study/create")
# 응답 모델로 Study 타입을 명시하여, 반환되는 JSON이 Study 모델 스펙을 따르도록 합니다.
def create_study(study: Study):
    max_index = -1
    if study_list:
        # Pydantic 모델에서 alias를 사용해도 실제 딕셔너리 키는 'index'가 아니므로,
        # 기존 로직 (dict.get("study_index")) 유지 또는 "index" 사용.
        # 여기서는 Pydantic 모델의 alias를 활용하여 .dict(by_alias=True) 사용
        max_index = max(s.get("study_index", -1) for s in study_list) # dict.get()을 사용하여 KeyError 방지
    
    new_study_index = max_index + 1

    # Pydantic 모델을 딕셔너리로 변환할 때 alias를 적용하여 실제 JSON 키를 사용하도록 합니다.
    new_study_data = study.dict(by_alias=True) # Pydantic 모델을 딕셔너리로 변환
    new_study_data["index"] = new_study_index # Flask 모델에서 index를 사용하므로
    # 추가 필드 (time, members_study_time)는 Flutter 모델에 없지만, 백엔드에서 필요하면 유지
    new_study_data["time"] = datetime.now().isoformat()
    # comments 필드도 초기화될 수 있도록 확인
    if "comments" not in new_study_data:
        new_study_data["comments"] = []
    if "members_study_time" not in new_study_data:
        new_study_data["members_study_time"] = {}


    study_list.append(new_study_data)
    # 반환할 때도 Flutter 모델에 맞춰 필드명을 다시 조정하여 반환합니다.
    return {"message": "스터디 생성 완료", "study": new_study_data}


@app.get("/studies", response_model=List[dict])
def get_all_studies():
    # study_list는 이미 Flutter 모델의 키 이름을 따르도록 위에서 수정했습니다.
    return study_list

@app.post("/study/{study_index}/comment") # 경로 변수명도 Flutter와 맞춤 (선택사항이지만 일관성을 위해)
def add_comment(study_index: int, comment: Comment):
    for study in study_list:
        if study.get("study_index") == study_index: # 변경: studyIndex -> study_index
            if "comments" not in study:
                study["comments"] = []
            study["comments"].append(comment.dict())
            return {"message": "댓글 추가 완료", "comments": study["comments"]}
    raise HTTPException(status_code=404, detail="해당 스터디를 찾을 수 없습니다.")

@app.get("/study/{study_index}") # 경로 변수명도 Flutter와 맞춤
def get_study(study_index: int):
    for study in study_list:
        if study.get("study_index") == study_index: # 변경: studyIndex -> study_index
            return {
                "study_index": study["study_index"],
                "title": study["title"],
                "description": study["description"],
                "description_more": study["description_more"],
                "author": study["author"],
                "members_study_time": study.get("members_study_time", {}),
                "study_time_log": study.get("study_time_log", {}),
                "comments": study.get("comments", []),
            }
    raise HTTPException(status_code=404, detail="스터디를 찾을 수 없습니다.")

@app.post("/study/{study_index}/update_study_time") # 경로 변수명도 Flutter와 맞춤
def update_study_time(study_index: int, update_data: StudyTimeUpdate):
    for study in study_list:
        if study.get("study_index") == study_index:

            # 1️⃣ 기존 누적 처리
            current_time = study.setdefault("members_study_time", {}).get(update_data.userName, 0)
            study["members_study_time"][update_data.userName] = current_time + update_data.duration_minutes

            # 2️⃣ 날짜별 공부 시간 기록 추가
            today = datetime.now().strftime("%Y-%m-%d")
            if "study_time_log" not in study:
                study["study_time_log"] = {}

            if today not in study["study_time_log"]:
                study["study_time_log"][today] = {}

            current_day_time = study["study_time_log"][today].get(update_data.userName, 0)
            study["study_time_log"][today][update_data.userName] = current_day_time + update_data.duration_minutes

            return {
                "message": "공부 시간 업데이트 완료",
                "members_study_time": study["members_study_time"],
                "study_time_log": study["study_time_log"]
            }

    raise HTTPException(status_code=404, detail="해당 스터디를 찾을 수 없습니다.")

# ----------------- 스터디 참여 및 조회 API -----------------

@app.post("/user/join-study")
def join_study(request_data: JoinStudyRequest):
    username_or_email = request_data.username 
    study_index = request_data.study_index # 이 변수는 이미 study_index

    user_data = users_db.get(username_or_email) 

    if not user_data:
        found_by_name = False
        for email, data in users_db.items():
            if data.get("name") == username_or_email:
                user_data = data
                username_or_email = email 
                found_by_name = True
                break
        if not found_by_name:
            raise HTTPException(status_code=404, detail="사용자를 찾을 수 없습니다. 올바른 이메일 또는 이름을 사용해주세요.")

    study_found = False
    for study in study_list:
        if study.get("study_index") == study_index: # 변경: studyIndex -> study_index
            study_found = True
            break
    
    if not study_found:
        raise HTTPException(status_code=404, detail="스터디를 찾을 수 없습니다.")

    if study_index in user_data.get("joined_studies", []):
        raise HTTPException(status_code=409, detail="이미 참여 중인 스터디입니다.")
    
    if "joined_studies" not in user_data:
        user_data["joined_studies"] = []
    user_data["joined_studies"].append(study_index)
    
    return {"message": "스터디에 성공적으로 참여했습니다!"}

@app.get("/user/{username_or_email}/joined-studies", response_model=List[dict])
def get_joined_studies(username_or_email: str):
    user_data = users_db.get(username_or_email) 

    if not user_data:
        found_by_name = False
        for email, data in users_db.items():
            if data.get("name") == username_or_email:
                user_data = data
                username_or_email = email 
                found_by_name = True
                break
        if not found_by_name:
            raise HTTPException(status_code=404, detail="사용자를 찾을 수 없습니다. 올바른 이메일 또는 이름을 사용해주세요.")

    joined_study_indices = user_data.get("joined_studies", [])
    
    joined_studies_details = []
    for index in joined_study_indices:
        for study in study_list:
            # 백엔드 스터디 리스트에 저장된 키는 이미 "study_index"입니다.
            if study.get("study_index") == index: # 변경: studyIndex -> study_index
                joined_studies_details.append(study)
                break
    
    return joined_studies_details

@app.get("/user/{username_or_email}/posts")
def get_user_posts(username_or_email: str):
    user_data = users_db.get(username_or_email)
    if not user_data:
        for email, data in users_db.items():
            if data.get("name") == username_or_email:
                user_data = data
                break
        if not user_data:
            raise HTTPException(status_code=404, detail="사용자를 찾을 수 없습니다.")

    name = user_data["name"]
    posts = []
    for study in study_list:
        if study.get("author") == name:
            posts.append({
                "title": study["title"],
                "subtitle": study["description"],
                "time": study.get("time", "N/A")
            })
    return posts

@app.get("/user/{username_or_email}/summary")
def get_user_summary(username_or_email: str):
    user_data = users_db.get(username_or_email)
    if not user_data:
        # 이름으로도 탐색
        for email, data in users_db.items():
            if data.get("name") == username_or_email:
                user_data = data
                break
        if not user_data:
            raise HTTPException(status_code=404, detail="사용자를 찾을 수 없습니다.")

    user_name = user_data["name"]
    joined_indices = user_data.get("joined_studies", [])

    total_minutes = 0
    posts = []

    for study in study_list:
        # 총 공부 시간 계산
        if study.get("study_index") in joined_indices:
            members_time = study.get("members_study_time", {})
            total_minutes += members_time.get(user_name, 0)

        # 내가 쓴 게시글 수집
        if study.get("author") == user_name:
            posts.append({
                "title": study["title"],
                "subtitle": study["description"],
                "time": study.get("time", "N/A")
            })

    return {
        "total_minutes": total_minutes,
        "posts": posts
    }

# ----------------- 서버 실행 -----------------
if __name__ == "__main__":
    uvicorn.run(app, host="127.0.0.1", port=8000)