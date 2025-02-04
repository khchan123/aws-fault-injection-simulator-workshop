#!/bin/env python3
# pip install mysql-connector-python
import mysql.connector
import random
import sys
import signal
import curses
import socket
import boto3
import json
import time

stdscr = curses.initscr()
curses.cbreak()

def signal_handler(sig, frame):
    print('You pressed Ctrl+C!')
    curses.nocbreak()
    curses.echo()
    curses.endwin()
    sys.exit(0)

signal.signal(signal.SIGINT, signal_handler)

def init_aurora():
    client = boto3.client('secretsmanager')
    # response = json.loads(client.get_secret_value(SecretId={{{auroraSecretArn}}}))
    response = json.loads(client.get_secret_value(SecretId='FisAuroraSecret')['SecretString'])

    mydb = mysql.connector.connect(
        user=response['username'],
        password=response['password'],
        host=response['host'],
        database=response['dbname'],
        connection_timeout=1
    )
    return response['host'], mydb

def init_rds():
    client = boto3.client('secretsmanager')
    # response = json.loads(client.get_secret_value(SecretId={{{mysqlSecretArn}}}))
    response = json.loads(client.get_secret_value(SecretId='FisMysqlSecret')['SecretString'])

    mydb = mysql.connector.connect(
        user=response['username'],
        password=response['password'],
        host=response['host'],
        database=response['dbname'],
        connection_timeout=1
    )
    return response['host'], mydb

aur_host, aur_con = init_aurora()
aur_cur           = aur_con.cursor()

rds_host, rds_con = init_rds()
rds_cur           = rds_con.cursor()

# for ii in range(1):
while True:
    aur_data=["%-30s" % "AURORA"]
    rds_data=["%-30s" % "RDS"]

    # Read aurora data
    try:
        aur_cur.execute("insert into test (value) values (%d)" % int(32768*random.random()))
        aur_con.commit()
        aur_cur.execute("select * from test order by id desc limit 10")
        aur_data.append("%-30s" % socket.gethostbyname(aur_host))
        for line in aur_cur:
            aur_data.append("%-30s" % str(line))
    except:
        try:
            aur_host, aur_con = init_aurora()
            aur_cur           = aur_con.cursor()
        except:
            pass

    # Read aurora data
    try:
        rds_cur.execute("insert into test (value) values (%d)" % int(32768*random.random()))
        rds_con.commit()
        rds_cur.execute("select * from test order by id desc limit 10")
        rds_data.append("%-30s" % socket.gethostbyname(rds_host))
        for line in rds_cur:
            rds_data.append("%-30s" % str(line))
    except:
        try:
            rds_host, rds_con = init_rds()
            rds_cur           = rds_con.cursor()
        except:
            pass

    # Print
    stdscr.clear()    
    for ii in range(12):
        aur_str = aur_data[ii] if len(aur_data)>ii else ' '*30
        rds_str = rds_data[ii] if len(rds_data)>ii else ' '*30
        # print("%s %s" % (aur_str,rds_str))
        stdscr.addstr(ii,0,"%s %s" % (aur_str,rds_str))
    stdscr.refresh()

    time.sleep(0.05)
