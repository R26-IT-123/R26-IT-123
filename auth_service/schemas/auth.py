from pydantic import BaseModel, field_validator


class RegisterRequest(BaseModel):
    email: str
    password: str
    full_name: str
    contact_number: str
    year: int
    semester: int

    @field_validator("email")
    @classmethod
    def must_be_sliit_email(cls, v: str) -> str:
        v = v.strip().lower()
        if not v.endswith("@my.sliit.lk"):
            raise ValueError("Must be a valid SLIIT student email ending in @my.sliit.lk")
        return v

    @field_validator("password")
    @classmethod
    def password_strength(cls, v: str) -> str:
        if len(v) < 6:
            raise ValueError("Password must be at least 6 characters.")
        return v

    @field_validator("year")
    @classmethod
    def validate_year(cls, v: int) -> int:
        if v not in (1, 2, 3, 4):
            raise ValueError("Year must be 1, 2, 3, or 4.")
        return v

    @field_validator("semester")
    @classmethod
    def validate_semester(cls, v: int) -> int:
        if v not in (1, 2):
            raise ValueError("Semester must be 1 or 2.")
        return v


class OTPVerifyRequest(BaseModel):
    email: str
    otp: str

    @field_validator("otp")
    @classmethod
    def validate_otp_format(cls, v: str) -> str:
        v = v.strip()
        if not v.isdigit() or len(v) != 6:
            raise ValueError("OTP must be a 6-digit number.")
        return v


class ResendOTPRequest(BaseModel):
    email: str


class RegisterResponse(BaseModel):
    message: str


class OTPVerifyResponse(BaseModel):
    uid: str
    message: str
    faculty: str
    student_id: str


class LoginRequest(BaseModel):
    email: str
    password: str

    @field_validator("email")
    @classmethod
    def must_be_sliit_email(cls, v: str) -> str:
        v = v.strip().lower()
        if not v.endswith("@my.sliit.lk"):
            raise ValueError("Must be a valid SLIIT student email ending in @my.sliit.lk")
        return v


class LoginResponse(BaseModel):
    custom_token: str
    uid: str
