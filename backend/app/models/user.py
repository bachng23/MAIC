from pydantic import BaseModel, EmailStr


class UserRegister(BaseModel):
    email: EmailStr
    password: str
    name: str
    phone: str | None = None
    language: str = "zh-TW"


class UserLogin(BaseModel):
    email: EmailStr
    password: str


class APNSTokenUpdate(BaseModel):
    apns_token: str


class UserOut(BaseModel):
    id: str
    email: str
    name: str
    phone: str | None
    language: str
