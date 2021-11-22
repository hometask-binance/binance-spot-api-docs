#!/bin/bash
#Binance Home Task

trap 'rm *json *txt *out' EXIT
export LC_NUMERIC=en_US.utf-8
API_URL="https://api.binance.com/api"

echo "Checking Test status of Binance API"
uri="/v3/ping"

HTTP_STATUS="$(curl -IL --silent "${API_URL}${uri}" | grep HTTP)";
HTTP_STATUS_NUM=`echo $HTTP_STATUS | cut -d' ' -f2 | xargs`
if [[ "$HTTP_STATUS_NUM" == "200" ]]; then
	echo "Binance API is reacheable."
else
	echo "Binance API is unreachable."
	exit 1
fi

Q1()
{
echo "======="
echo ""
echo "Printing the top 5 symbols with quote asset BTC and the highest volume over the last 24 hours in descending order."
echo ""

API_URL="https://api.binance.com/api"
uri="/v3/ticker/24hr"
curl -s -i -H "Accept: application/json" -H "Content-Type: application/json" -X GET "$API_URL$uri" | sed 's:^.\(.*\).$:\1:' | sed '1,26d' > btc.json
sed -i "s/,{/\n{/g" btc.json
cat btc.json | jq > /dev/null
timestamp=$(($(date +%s%N)/1000000))
timestamp24=$((timestamp - 24 * 60 * 1000))
jq -r '([.symbol,.volume,.closeTime]) | @tsv' btc.json | column -t | nl -v 0  | awk '/BTC/ && $3 > $timestamp24 || NR==1' > btc.out
cat btc.out | awk {'print $1"\t"$2"\t"$3'} | column -t | sort -k 3rn | head -5 |  awk '{print $2}' > symbols_BTC.txt
cat btc.out | awk {'print $1"\t"$2"\t"$3'} | column -t | sort -k 3rn | head -5 | awk -v FS="," 'BEGIN{print "\tsymbol\t\tvolume"}{printf "%s\t%s%s",$1,$2,ORS}'
}

Q2()
{
echo "======="
echo ""
echo "Printing the top 5 symbols with quote asset USDT and the highest number of trades over the last 24 hours in descending order."
echo ""

API_URL="https://api.binance.com/api"
uri="/v3/ticker/24hr"
curl -s -i -H "Accept: application/json" -H "Content-Type: application/json" -X GET "$API_URL$uri" | sed 's:^.\(.*\).$:\1:' | sed '1,26d' > usdt.json
sed -i "s/,{/\n{/g" usdt.json
cat usdt.json | jq > /dev/null
timestamp=$(($(date +%s%N)/1000000))
timestamp24=$((timestamp - 24 * 60 * 1000))
jq -r '([.symbol,.count,.closeTime]) | @tsv' usdt.json | column -t | nl -v 0  | awk '/USDT/ && $3 > $timestamp24 || NR==1' > usdt.out
cat usdt.out | awk {'print $1"\t"$2"\t"$3'} | column -t | sort -k 3rn | head -5 |  awk '{print $2}' > symbols_USDT.txt
cat usdt.out | awk {'print $1"\t"$2"\t"$3'} | column -t | sort -k 3rn | head -5 | awk -v FS="," 'BEGIN{print "\tsymbol\t\tcount"}{printf "%s\t%s%s",$1,$2,ORS}'
}

bids()
{
SUM=0
sed -n '/bids/,/asks/p' notional.json | sed '1,2d' | sed '$d' | paste -d, - - | sed -n '/[^ ,]/p' | column -t | sort -k 1rn | head -200 > notional_bids.json
		while read line
		do
			f1=`echo $line| cut -d',' -f1`
			f2=`echo $line| cut -d',' -f2`
			MUL=$(echo $f1 $f2 | awk '{printf "%4.3f\n",$1*$2}')
			SUM=`echo $SUM + $MUL | bc`
		done < notional_bids.json
		echo "'"${entry}_bids"'": $SUM,
}

asks()
{
SUM=0
sed -n '/asks/,/}/p' notional.json | sed '1,2d' | sed '$d' | paste -d, - - | sed -n '/[^ ,]/p' | column -t | sort -k 1rn | head -200 > notional_asks.json
		while read line
		do
			f1=`echo $line| cut -d',' -f1`
			f2=`echo $line| cut -d',' -f2`
			MUL=$(echo $f1 $f2 | awk '{printf "%4.3f\n",$1*$2}')
			SUM=`echo $SUM + $MUL | bc`
		done < notional_asks.json
		echo "'"${entry}_asks"'": $SUM,
}

Q3()
{
echo "======="
echo ""
echo "Printing the total notional value of the top 200 bids and asks currently on each symbol with quote asset BTC"
echo ""

API_URL="https://api.binance.com/api"
uri="/v3/depth"
echo "" >> symbols_BTC.txt
echo "{"
cat symbols_BTC.txt | while read entry; do
	len=`echo $entry|awk '{print length}'`
	if [ $len -gt 1 ];  then
		curl -s -i -H "Accept: application/json" -H "Content-Type: application/json" -X GET "$API_URL$uri?symbol=$entry" | sed '1,26d' | jq | awk 'NR>2' > notional.json
		sed -i "s|\[||g" notional.json
		sed -i "s|]||g" notional.json
		sed -i "s|,||g" notional.json
		sed "s/^[ \t]*//" -i notional.json
		sed -i 's|"||g' notional.json
		bids &
		asks &
		wait
	fi
done
echo "}"
}

Q4()
{
echo "======="
echo ""
echo "Printing the price spread for each of the symbol with quote asset USDT"
echo ""

if [ -f usdt_ps_old.txt ]; then
	rm usdt_ps_old.txt
fi
API_URL="https://api.binance.com/api"
uri="/v3/ticker/bookTicker"
echo "" >> symbols_USDT.txt
echo "{"
cat symbols_USDT.txt | while read entry; do
	len=`echo $entry|awk '{print length}'`
	if [ $len -gt 1 ];  then
		curl -s -i -H "Accept: application/json" -H "Content-Type: application/json" -X GET "$API_URL$uri?symbol=$entry" | sed '1,25d' > price_spread.json
		val=`jq -r '([.bidPrice,.askPrice]) | @tsv' price_spread.json | sed 's/\t/,/g'`
		f1=`echo $val| cut -d',' -f1`
		f2=`echo $val| cut -d',' -f2`
		SUB=$(echo "($f2-$f1)"| bc -l)
		echo "'"${entry}"'": $SUB,
		echo ${entry},$SUB >> usdt_ps_old.txt
	fi
done
echo "}"
}

Q5()
{
echo "======="
echo ""
echo "[Printing every 10 seconds result of price spread for each of the symbol with quote asset USDT and the absolute delta from the previous value]"
echo ""
sleep 10

if [ -f usdt_ps_new.txt ]; then
	rm usdt_ps_new.txt
fi
echo "{"
API_URL="https://api.binance.com/api"
uri="/v3/ticker/bookTicker"
cat symbols_USDT.txt | while read entry; do
	len=`echo $entry|awk '{print length}'`
	if [ $len -gt 1 ];  then
		curl -s -i -H "Accept: application/json" -H "Content-Type: application/json" -X GET "$API_URL$uri?symbol=$entry" | sed '1,25d' > price_spread.json
		val=`jq -r '([.bidPrice,.askPrice]) | @tsv' price_spread.json | sed 's/\t/,/g'`
		f1=`echo $val| cut -d',' -f1`
		f2=`echo $val| cut -d',' -f2`
		SUB=$(echo "($f2-$f1)"| bc -l)
		echo "'"${entry}"'": $SUB,
		curl -s -X POST -H "Content-type: text/plain" --data price_spread{${entry}= /\$SUB} http://localhost:8080/metrics/job/price_spread/instance/localhost #Query in Prometheus Metrics format.
		echo ${entry},$SUB >> usdt_ps_new.txt
	fi
done
echo "}"
paste -d',' usdt_ps_old.txt usdt_ps_new.txt > usdt_ps_diff.txt
while read line; do
f1=`echo $line| cut -d',' -f1`
f2=`echo $line| cut -d',' -f2`
f4=`echo $line| cut -d',' -f4`
SUB=$(echo "($f2-$f4)"| bc -l)
echo "Absolute Delta for $f1: $SUB"
curl -s -X POST -H "Content-type: text/plain" --data absolute_delta{${f1}= /\$SUB} http://localhost:8080/metrics/job/absolute_delta/instance/localhost #Query in Prometheus Metrics format.
done < usdt_ps_diff.txt
cp usdt_ps_new.txt usdt_ps_old.txt
}

Q1
Q2
Q3
Q4
while true
do 
    Q5
    sleep 1
done
