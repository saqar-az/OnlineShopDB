import tokenize
from fastapi import FastAPI, HTTPException, Depends,Query,status
from pydantic import BaseModel
from sqlalchemy import Column, DateTime, Integer, String, Numeric, ForeignKey, delete, func, Boolean, update
from sqlalchemy.ext.asyncio import AsyncSession,create_async_engine
from sqlalchemy.orm import sessionmaker, declarative_base, relationship
from sqlalchemy.future import select
from sqlalchemy.dialects.postgresql import ARRAY, JSONB
from typing import Optional
from passlib.context import CryptContext
from fastapi.security import OAuth2PasswordBearer, OAuth2PasswordRequestForm
from jwt.exceptions import InvalidTokenError
import jwt
from datetime import datetime, timedelta, timezone

DATABASE_URL = "postgresql+asyncpg://username:password@localhost/db_name"

SECRET_KEY = "09d25e094faa6ca2556c818166b7"
ALGORITHM = "HS256"
ACCESS_TOKEN_EXPIRE_MINUTES = 30

engine = create_async_engine(DATABASE_URL, echo=True)
AsyncSessionLocal = sessionmaker(bind=engine, class_=AsyncSession, expire_on_commit=False)
Base = declarative_base()

pwd_context = CryptContext(schemes=["bcrypt"], deprecated="auto")
oauth2_scheme = OAuth2PasswordBearer(tokenUrl="login")

class Customer(Base):
    __tablename__ = 'customer'
    customer_id = Column(Integer, primary_key=True, index=True)
    first_name = Column(String(100), nullable=False)
    last_name = Column(String(100), nullable=False)
    password = Column(String(100), nullable=False)    
    username = Column(String(30), unique=True, nullable=False)
    wallet_balance = Column(Numeric(10, 2), default=0.00)
    phone_numbers = Column(ARRAY(String), nullable=True)

class Address(Base):
    __tablename__ = 'address'
    address_id = Column(Integer, primary_key=True, index=True)
    street_name = Column(String(50), nullable=False)
    street_number = Column(String(30), nullable=False)
    country = Column(String(30), nullable=False)
    city = Column(String(30), nullable=False)
    postal_code = Column(String(30), nullable=False)
    province = Column(String(30), nullable=False)
    customer_id = Column(Integer, ForeignKey('customer.customer_id'), nullable=False)

class Category(Base):
    __tablename__ = 'category'
    category_id = Column(Integer, primary_key=True, autoincrement=True)
    name = Column(String(50), nullable=False)

class Product(Base):
    __tablename__ = 'product'
    product_id = Column(Integer, primary_key=True, autoincrement=True)
    name = Column(String(100), nullable=False)
    price = Column(Numeric(10, 2), nullable=False)
    stock_count = Column(Integer, nullable=False)
    category_id = Column(Integer, ForeignKey('category.category_id'))
    rating = Column(Numeric(5, 2), default=0.00)

class Review(Base):
    __tablename__ = 'review'
    review_id = Column(Integer, primary_key=True, autoincrement=True)
    rating = Column(Integer, nullable=False)
    comment = Column(ARRAY(String), nullable=True)
    customer_id = Column(Integer, ForeignKey('customer.customer_id'), nullable=False)
    product_id = Column(Integer, ForeignKey('product.product_id'), nullable=False)

class FavoriteList(Base):
    __tablename__ = 'favorite_list'
    favorite_id = Column(Integer, primary_key=True, autoincrement=True)
    total_price = Column(Numeric(10, 2), default=0.00)
    create_date = Column(DateTime, nullable=False, default=func.now())
    customer_id = Column(Integer, ForeignKey('customer.customer_id'), unique=True, nullable=False)

class FavoriteListItem(Base):
    __tablename__ = 'favorite_list_items'
    favorite_id = Column(Integer, ForeignKey('favorite_list.favorite_id'), primary_key=True)
    product_id = Column(Integer, ForeignKey('product.product_id'), primary_key=True)
    quantity = Column(Integer, nullable=False)

class Order(Base):
    __tablename__ = 'order'
    order_id = Column(Integer, primary_key=True, autoincrement=True)
    order_date = Column(DateTime, nullable=False, default=func.now())
    total_price = Column(Numeric(10, 2), default=0.00)
    status = Column(Boolean, nullable=False)
    customer_id = Column(Integer, ForeignKey('customer.customer_id'), nullable=False)
    address_id = Column(Integer, ForeignKey('address.address_id'), nullable=False)

class Payment(Base):
    __tablename__ = 'payment'
    payment_id = Column(Integer, primary_key=True, autoincrement=True)
    amount = Column(Numeric(10, 2), nullable=False)
    method = Column(String(30), nullable=False)
    payment_date = Column(DateTime, nullable=False, default=func.now())
    order_id = Column(Integer, ForeignKey('order.order_id'), nullable=False)
    customer_id = Column(Integer, ForeignKey('customer.customer_id'), nullable=False)

class OrderItem(Base):
    __tablename__ = 'order_items'
    quantity = Column(Integer, nullable=False)
    order_id = Column(Integer, ForeignKey('order.order_id'), primary_key=True)
    product_id = Column(Integer, ForeignKey('product.product_id'), primary_key=True)

class DiscountCode(Base):
    __tablename__ = 'discount_code'
    discount_id = Column(Integer, primary_key=True, autoincrement=True)
    code = Column(String(30), unique=True, nullable=False)
    percentage = Column(Numeric(5, 2), nullable=False)
    status = Column(Boolean, nullable=False)
    order_id = Column(Integer, ForeignKey('order.order_id'), nullable=False)

class GiftCard(Base):
    __tablename__ = 'gift_card'
    gift_id = Column(Integer, primary_key=True, autoincrement=True)
    value = Column(Numeric(10, 2), nullable=False)
    code = Column(String(30), unique=True, nullable=False)
    status = Column(Boolean, nullable=False)
    order_id = Column(Integer, ForeignKey('order.order_id'), nullable=False)

class OrderHistoryLog(Base):
    __tablename__ = 'order_history_log'
    log_id = Column(Integer, primary_key=True, autoincrement=True)
    customer_id = Column(Integer, ForeignKey('customer.customer_id'), nullable=False)
    order_id = Column(Integer, ForeignKey('order.order_id'), nullable=False)
    order_details = Column(JSONB, nullable=False)
    logged_at = Column(DateTime, nullable=False, default=func.now())

async def init_db():
    async with engine.begin() as conn:
        await conn.run_sync(Base.metadata.create_all)

app = FastAPI()

@app.on_event("startup")
async def startup_event():
    await init_db()

@app.on_event("shutdown")
async def shutdown_event():
    await engine.dispose()

def verify_password(plain_password, hashed_password):
    return pwd_context.verify(plain_password, hashed_password)

def get_password_hash(password):
    return pwd_context.hash(password)

def create_access_token(data: dict, expires_delta: timedelta | None = None):
    to_encode = data.copy()
    if expires_delta:
        expire = datetime.now(timezone.utc) + expires_delta
    else:
        expire = datetime.now(timezone.utc) + timedelta(minutes=15)
    to_encode.update({"exp": expire})
    encoded_jwt = jwt.encode(to_encode, SECRET_KEY, algorithm=ALGORITHM)
    return encoded_jwt

async def get_current_user(token: str = Depends(oauth2_scheme)):
    credentials_exception = HTTPException(
        status_code=status.HTTP_401_UNAUTHORIZED,
        detail="Could not validate credentials",
        headers={"WWW-Authenticate": "Bearer"},
    )
    try:
        payload = jwt.decode(token, SECRET_KEY, algorithms=[ALGORITHM])
        username: str = payload.get("sub")
        if username is None:
            raise credentials_exception
        token_data = TokenData(username=username)
    except jwt.PyJWTError:
        raise credentials_exception

    async with AsyncSessionLocal() as session:
        user = await get_user(session, token_data.username)

    if user is None:
        raise credentials_exception
    return user


async def get_user(session: AsyncSession, username: str):
    result = await session.execute(select(Customer).where(Customer.username == username))
    return result.scalar_one_or_none()


async def authenticate_user(session: AsyncSession, username: str, password: str):
    user = await get_user(session, username)
    if not user:
        return False
    if not verify_password(password, user.password):
        return False
    return user

class TokenData(BaseModel):
    username: str | None = None

class CustomerCreate(BaseModel):
    first_name: str
    last_name: str
    password: str
    username: str
    phone_numbers: list[str]

class AddressResponse(BaseModel):
    address_id: int
    street_name: str
    street_number: str
    country: str
    city: str
    postal_code: str
    province: str

class ProductResponse(BaseModel):
    product_id: int
    name: str
    price: float
    stock_count: int
    rating: Optional[float]

class OrderDetailsResponse(BaseModel):
    order_id: int
    total_price: float
    status: bool
    products: list[ProductResponse]

class ProductParams(BaseModel):
    category_name: Optional[str] = Query(None, description="name of the product category")
    min_price: Optional[float] = Query(None, description="min price of the product")
    max_price: Optional[float] = Query(None, description="max price of the product")    

class OrderStatus(BaseModel):
    status: bool

class LoginResponse(BaseModel):
    access_token: str
    token_type: str
    message: str

class CustomerUpdate(BaseModel):
    first_name: Optional[str] = None
    last_name: Optional[str] = None
    password: Optional[str] = None
    phone_numbers: Optional[list[str]] = None


@app.post("/login", response_model=LoginResponse)
async def login_for_access_token(form_data: OAuth2PasswordRequestForm = Depends()):
    async with AsyncSessionLocal() as session:
        user = await authenticate_user(session, form_data.username, form_data.password)
        if not user:
            raise HTTPException(
                status_code=status.HTTP_401_UNAUTHORIZED,
                detail="Incorrect username or password",
                headers={"WWW-Authenticate": "Bearer"},
            )
        access_token_expires = timedelta(minutes=ACCESS_TOKEN_EXPIRE_MINUTES)
        access_token = create_access_token(
            data={"sub": user.username}, expires_delta=access_token_expires
        )
        return LoginResponse(
            access_token=access_token,
            token_type="bearer",
            message=f"logged in successfully as {user.username}"       
        )
    

@app.put("/customer/update", response_model=dict)
async def update_customer(customer_update: CustomerUpdate, current_user: Customer = Depends(get_current_user)):
    async with AsyncSessionLocal() as session:
        async with session.begin():
            update_data = {}
            if customer_update.first_name is not None:
                update_data["first_name"] = customer_update.first_name
            if customer_update.last_name is not None:
                update_data["last_name"] = customer_update.last_name
            if customer_update.password is not None:
                update_data["password"] = get_password_hash(customer_update.password)
            if customer_update.phone_numbers is not None:
                update_data["phone_numbers"] = customer_update.phone_numbers

            if not update_data:
                raise HTTPException(status_code=400, detail="No field to update")

            await session.execute(update(Customer).where(Customer.username == current_user.username).values(**update_data))
            await session.commit()

    access_token_expires = timedelta(minutes=ACCESS_TOKEN_EXPIRE_MINUTES)
    new_access_token = create_access_token(data={"sub": current_user.username}, expires_delta=access_token_expires)

    return {
        "message": "customer properties updated successfully.",
        "access_token": new_access_token,
        "token_type": "bearer"
    }


@app.delete("/customer/delete", response_model=dict)
async def delete_customer(password: str, current_user: Customer = Depends(get_current_user)):
    async with AsyncSessionLocal() as session:
        async with session.begin():
            if not verify_password(password, current_user.password):
                raise HTTPException(status_code=400, detail="incorrect password")

            await session.execute(delete(Customer).where(Customer.username == current_user.username))
            await session.commit()

    return {"message": "customer deleted successfully."}


@app.post("/customer/")
async def create_customer(customer: CustomerCreate):
    async with AsyncSessionLocal() as session:
        async with session.begin():
            existing_user = await get_user(session, customer.username)
            if existing_user:
                raise HTTPException(status_code=400, detail="username already taken. choose another one")

            new_customer = Customer(
                first_name=customer.first_name,
                last_name=customer.last_name,
                password=get_password_hash(customer.password),
                username=customer.username,
                phone_numbers=customer.phone_numbers
            )
            session.add(new_customer)
            await session.commit()

        return {"message": "customer created successfully!"}


@app.get("/addresses/{user_id}", response_model=list[AddressResponse])
async def get_addresses(user_id: int):
    async with AsyncSessionLocal() as session:
        async with session.begin():
            result = await session.execute(
                select(Address).where(Address.customer_id == user_id)
            )
            addresses = result.scalars().all()
            if not addresses:
                raise HTTPException(status_code=404, detail="no address found for this customer")

            return [AddressResponse(
                address_id=address.address_id,
                street_name=address.street_name,
                street_number=address.street_number,
                country=address.country,
                city=address.city,
                postal_code=address.postal_code,
                province=address.province
            ) for address in addresses]


@app.get("/orders/{order_id}", response_model=OrderDetailsResponse)
async def get_order_details(order_id: int):
    async with AsyncSessionLocal() as session:
        async with session.begin():
            order_query = await session.execute(
                select(Order).where(Order.order_id == order_id)
            )
            order = order_query.scalar_one_or_none()

            if not order:
                raise HTTPException(status_code=404, detail="order not found")

            order_items_query = await session.execute(
                select(OrderItem).where(OrderItem.order_id == order_id)
            )
            order_items = order_items_query.scalars().all()

            products = []
            for item in order_items:
                product_query = await session.execute(
                    select(Product).where(Product.product_id == item.product_id)
                )
                product = product_query.scalar_one_or_none()
                if product:
                    products.append(ProductResponse(
                        product_id=product.product_id,
                        name=product.name,
                        price=float(product.price),
                        stock_count=product.stock_count,          
                        rating=float(product.rating) if product.rating is not None else None 
        ))

            return OrderDetailsResponse(
                order_id=order.order_id,
                total_price=float(order.total_price),
                status=order.status,
                products=products
                
            )
# get products list based on price range or category :

@app.get("/products/", response_model=list[ProductResponse])
async def get_products(filters: ProductParams = Depends()):
    async with AsyncSessionLocal() as session:
        async with session.begin():    
            query = select(Product)

            category_id = None
            if filters.category_name is not None:
                category_query = select(Category).where(Category.name == filters.category_name)
                category_result = await session.execute(category_query)
                category = category_result.scalars().first()
                if category:
                    category_id = category.category_id   

            if category_id is not None:
                query = query.where(Product.category_id == category_id)
            if filters.min_price is not None:
                query = query.where(Product.price >= filters.min_price)
            if filters.max_price is not None:
                query = query.where(Product.price <= filters.max_price)     

            result = await session.execute(query)
            products = result.scalars().all()

            return [
                ProductResponse(
                    product_id=product.product_id,
                    name=product.name,
                    price=float(product.price),
                    stock_count=product.stock_count,
                    rating=float(product.rating) if product.rating is not None else None
                )
                for product in products
            ]


@app.get("/orders/{order_id}/status", response_model=OrderStatus)
async def get_order_status(order_id: int):
    async with AsyncSessionLocal() as session:
        async with session.begin():
            order_query = await session.execute(
                select(Order).where(Order.order_id == order_id)
            )
            order = order_query.scalar_one_or_none()

            if not order:
                raise HTTPException(status_code=404, detail="order not found")

            return OrderStatus(
                status=order.status
            )