#!/bin/bash
#wordlist=/usr/share/wordlists/dirb/common.txt 
# Function to find IP addresses on the network
find_ip_addresses() {
    sudo netdiscover -r 192.168.200.0/24 -P -N | awk '/192\.168\./ {print $1}' > ip_addresses.txt  
}

# Function to perform nmap scan on the extracted IP addresses
nmap_scan() {
    # Check if the ip_addresses.txt file exists
    if [ ! -f "ip_addresses.txt" ]; then
        echo "Error: ip_addresses.txt not found. Run the find_ip_addresses function first."
        exit 1
    fi

    #extract the third IP address using head and tail
    third_ip_address=$(cat ip_addresses.txt | awk 'NR==3 {print}')
   
   #check if the third IP address is empty     
    if [ -z "$third_ip_address" ]; then
        echo "error: third ip address not found"
       	exit 1
    fi
    
    echo "Scanning third IP address: $third_ip_address"
    nmap -p 21,80,445 -A --script vuln "$third_ip_address"  
}

echo "Scanning the network for IP addresses..."
find_ip_addresses

echo "IP addresses found and saved to ip_addresses.txt."

echo "Performing nmap scan on the found IP addresses..."
nmap_scan > nmap.txt

if grep -q '80/tcp\s\+open' nmap.txt; then
	echo 'Port 80 is open. Running Whatweb...'
	#run whatweb on port 80
	whatweb "http://$third_ip_address" > netscan_result.txt	
	#run nikto on port 80
	#nikto -h "http://$third_ip_address" >> netscan_result.txt	

echo 'Testing directory brute force on port 80...'
	#ffuf -u "http://$third_ip_address/FUZZ" -w $wordlist -mc 200,301,302,307 -c -v -e .php,.asp,.aspx,.jsp,.html,.htm,.js,.cgi > fuff.txt
	dirb "http://$third_ip_address/" >> netscan_result.txt
else 
	echo 'Port 80 is closed.'
fi

#check if port 21 is open
#if grep -q '21/tcp' "open" nmap.txt; then
if grep -q '21/tcp\s\+open' nmap.txt; then
	echo 'Port 21 is open. Testing for anonymous FTP access ...'
	ftp -n $third_ip_address >> netscan_result.txt
else
	echo "Port 21 is closed"
fi

if grep -q '445/tcp\s\+open' nmap.txt; then
	echo 'Port 445 is open. Testing for anonymous guest SMB access ...'
	smbclient -N -L //$third_ip_address >> netscan_result.txt
else
	echo 'Port 445 is closed.'
fi

#Display results
echo
echo '---- Results ----'
echo 'Network Scan Results'
cat nmap.txt

if [[ -s netscan_result.txt ]]; then
	echo 'Nikto Results'
	cat netscan_result.txt
else 
	echo 'file doesnt exist'
fi
