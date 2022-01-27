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

conn.autocommit = True
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
            message_id = None
            if msg.command.split(" :", 1)[0][:7] == 'PRIVMSG':
                cur.callproc('log_message',(id,name,privmsg))
                message_id = cur.fetchone()[0]
                print(message_id)
                if(privmsg[0] == "!"):
                    cmd = privmsg.split(" ")[0]
                    if cmd == "!ping":
                        await client.send_privmsg("@"+name+": PONG!")
                    elif cmd == "!start" and name == config['IRC']['channel']:
                        cur.callproc('sessions_start')
                        sessionid = cur.fetchone()[0]
                        await client.send_privmsg("SessionID: {:d} started!".format(sessionid))
                    elif cmd == "!vibecheck" and name == config['IRC']['channel']:
                        cur.callproc('vibechecks_start',(message_id,))
                        vibecheck_id = cur.fetchone()[0]
                        await client.send_privmsg("VibeCheck: {:d} started! Check in by sending !vibin in chat in the next 5 minutes. If you send it after that you will lose vibe points!".format(vibecheck_id))
                    elif cmd == "!vibin":
                        cur.callproc('vibeins_submit',(message_id,))
                        vibein_vibecheck_id = cur.fetchone()[0]
                        if vibein_vibecheck_id == None:
                            await client.send_privmsg("@{:s} Ya done goofed! No vibe check is active!!".format(name))
                        else:
                            await client.send_privmsg("@{:s} You got a vibe point for vibecheck: {:d}!".format(name,vibein_vibecheck_id))
                    elif cmd == "!stop" and name == config['IRC']['channel']:
                        cur.callproc('sessions_stop',(sessionid,))
                        stoppedsession = cur.fetchone()[0]
                        if sessionid == stoppedsession:
                            await client.send_privmsg("Session #{:d} stopped!".format(stoppedsession))
                            sessionid = None
                        else:
                            await client.send_privmsg("Unable to stop session #{:d}!".format(sessionid))
                    elif cmd == "!kill" and name == config['IRC']['channel']:
                        await client.send_privmsg("Seeya!")
                        exit()
                print(name,'(',id,'): ',privmsg)
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



