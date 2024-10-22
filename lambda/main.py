import requests

def handler(event, context):
    url = 'https://api.github.com/users'
    if event['queryStringParameters'] and 'user_id' in event['queryStringParameters']:
        url += '/' + event['queryStringParameters']['user_id']
    return {
        'statusCode': 200,
        'headers': {'Content-type': 'application/json'},
        'body': requests.get(url).text
    }

if __name__ == '__main__':
    print(handler({'queryStringParameters': {'user_id': 'skaasguru'}}, None))
