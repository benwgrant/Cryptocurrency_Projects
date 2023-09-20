# Fetch the price of bitcoin and print it to the console
def get_btc_price():
    response = requests.get('https://api.coindesk.com/v1/bpi/currentprice.json')
    response_json = response.json()
    print("Bitcoin price: " + response_json['bpi']['USD']['rate'])
    return response_json['bpi']['USD']['rate']