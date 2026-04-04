import requests,pyodbc,datetime
API_KEY = "db9857b05ca64f90aa9e60f477484592"
tickers = ['CEG','MP','XOM','F','RR','RBW','SHEL','VOW3','015760.KS','GMDCLTD','ONGC','TMPV']
conn= pyodbc.connect(
	"Driver = {ODBC Driver 17 for SQL Server'};"
	"Server = localhost;"
	"Database = Global_Portfolio_Analysis;"
	"Trusted_Connection = yes;"
)
cursor=conn.cursor()
for ticker in tickers:
	url = f"https://api.twelvedata.com/time_series?symbol={ticker}&interval=1day&start_date=2024-03-28&end_date=2026-03-28&apikey={API_KEY}
        response = requests.get(url)
	data=response.json()
	for record in data["values"]:
		cursor.execute(
		  "INSERT INTO bronze_stock_prices (ticker, trade_date, open_price, high_price, low_price, close_price, volume, exchange, currency, api_fetched_at) VALUES (?,?,?,?,?,?,?,?,?,?)",
            	  (ticker, record["datetime"], record["open"], record["high"], record["low"], record["close"], record["volume"], data["meta"]["exchange"], data["meta"]["currency"], datetime.datetime.now())
	)
conn.commit()
conn.close()