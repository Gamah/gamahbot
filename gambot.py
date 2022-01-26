import sys
import datetime
import asyncio
from click import command
from paramiko import Channel
import pytmi
import configparser
import psycopg2

config = configparser.ConfigParser()
config.read('config.ini')

conn = psycopg2.connect(
    host='localhost',
    database=config['DB']['dbname'],
    user=config['DB']['user'],
    password=config['DB']['pass'])

cur = conn.cursor()
sessionid = None

async def main() -> None:

    client = pytmi.TmiClient()
    await client.login_oauth(config['IRC']['oAuth'], config['IRC']['nick'])
    await client.join(config['IRC']['channel'])
    await client.send_privmsg("GamahBot, online!")
    
    while True:
        #await asyncio.sleep(1)
        try:
            raw = await client.get_privmsg()
            msg = pytmi.TmiMessage(raw.lstrip())

            print(msg.raw,"\n")
            privmsg = msg.command.split(" :", 1)[1]
            name = msg.tags.get("display-name")
            id = msg.tags.get("user-id")

            if(privmsg[0] == "!"):
                cmd = privmsg.split(" ")[0]
                if cmd == "!ping":
                    await client.send_privmsg("@"+name+": PONG!")
                elif cmd == "!start" and name == config['IRC']['channel']:
                    cur.execute("CALL sessions_start();")
                    sessionid = cur.fetchone()[0]
                    conn.commit()
                    await client.send_privmsg("SessionID: {:d} started!".format(sessionid))
                elif cmd == "!stop" and name == config['IRC']['channel']:
                    cur.execute("CALL sessions_stop({:d});".format(sessionid))
                    conn.commit()
                    await client.send_privmsg("Session #{:d} stopped!".format(sessionid))
                    sessionid = None
                elif cmd == "!kill" and name == config['IRC']['channel']:
                    await client.send_privmsg("Seeya!")
                    exit()
            print(name,"(",id,"): ",privmsg)
            
            del raw
            del msg

        except OSError:
            raise
        except Exception:
            continue


if __name__ == "__main__":
    try:
        loop = asyncio.new_event_loop()
        loop.run_until_complete(main())
    except KeyboardInterrupt:
        sys.exit(0)
    except Exception:
        raise