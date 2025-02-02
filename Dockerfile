FROM python:3.6-alpine

RUN pip install flask

COPY . /opt/

EXPOSE 8090

WORKDIR /opt

ENTRYPOINT ["python", "app.py"]
