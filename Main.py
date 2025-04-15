from typing import Union

from fastapi import FastAPI, HTTPException
 
from pydantic import BaseModel


app = FastAPI()
class Item(BaseModel):
    name: str
    price: float
    is_offer: Union[bool, None] = None
    
class DB_manager():

    def __init__(self) -> None:
        self.db = {}

    def get(self, id: int):
        return self.db.get(id)
    
    def insert(self, id: int, item: Item):
        self.db[id] = item


db_manager = DB_manager()


@app.get("/items/{item_id}")
def read_item(item_id: int, q: Union[str, None] = None):
    return db_manager.get(item_id)


@app.put("/items/{item_id}")
def update_item(item_id: int, item: Item):

    db_manager.insert(item_id, item)
    return {"item_name": item.name, "item_id": item_id}