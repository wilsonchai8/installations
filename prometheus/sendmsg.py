from tornado.ioloop import IOLoop
import tornado.httpserver as httpserver
import tornado.web
import requests
import json

WEBHOOK_URL = 'https://open.feishu.cn/open-apis/bot/v2/hook/df773ad8-e1f0-4b89-8544-bfebbacd22e9'

def send_to_feishu(msg_raw):
    headers = { 'Content-Type': 'application/json' }
    for alert in msg_raw['alerts']:
        msg = '## 告警发生 ##\n'
        msg += '\n'
        msg += '告警：{}\n'.format(alert['labels']['alertname'])
        msg += '时间：{}\n'.format(alert['startsAt'])
        msg += '级别：{}\n'.format(alert['labels']['severity'])
        msg += '详情：\n'
        msg += '    deploy：{}\n'.format(alert['labels']['deployment'])
        msg += '    namespace：{}\n'.format(alert['labels']['namespace'])
        msg += '    content：{}\n'.format(alert['annotations']['summary'])
        data = {
            'msg_type': 'text',
            'content': {
                'text': msg
            }
        }
        res = requests.Session().post(url=WEBHOOK_URL, headers=headers, json=data)
        print(res.json())

class SendmsgFlow(tornado.web.RequestHandler):
    def post(self, *args, **kwargs):
        send_to_feishu(json.loads(self.request.body.decode('utf-8')))

def applications():
    urls = []
    urls.append([r'/sendmsg', SendmsgFlow])
    return tornado.web.Application(urls)

def main():
    app = applications()
    server = httpserver.HTTPServer(app)
    server.bind(10000, '0.0.0.0')
    server.start(1)
    IOLoop.current().start()

if __name__ == "__main__":
    try:
        main()
    except KeyboardInterrupt as e:
        IOLoop.current().stop()
    finally:
        IOLoop.current().close()

