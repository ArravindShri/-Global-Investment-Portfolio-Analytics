import requests, pyodbc, datetime

API_KEY = "Your API KEY- DUH its a premium service bro"
pairs = ["USD/INR", "GBP/INR", "EUR/INR"]

conn = pyodbc.connect(
    "Driver={ODBC Driver 17 for SQL Server};"
    "Server=localhost;"
    "Database=Global_Portfolio_Analysis;"
    "Trusted_Connection=yes;"
)
cursor = conn.cursor()

for pair in pairs:
    print(f"Fetching {pair}...")
    url = f"https://api.twelvedata.com/time_series?symbol={pair}&interval=1day&outputsize=1&apikey={API_KEY}"
    response = requests.get(url)
    data = response.json()
    if data.get("status") == "error":
        print(f"ERROR for {pair}: {data['message']}")
        continue
    count = 0
    for record in data["values"]:
        try:
            cursor.execute(
                "INSERT INTO bronze_forex_rates (currency_pair, trade_date, open_rate, close_rate, high_rate, low_rate, api_fetched_at) VALUES (?,?,?,?,?,?,?)",
                (pair, record["datetime"], record["open"], record["close"], record["high"], record["low"], datetime.datetime.now())
            )
            count += 1
        except:
            print(f"Skipped {pair} {record['datetime']} - already exists")
    print(f"Inserted {count} records for {pair}")

conn.commit()
print("Done! All data committed.")
conn.close()
