import hashlib
import binascii
import rsa
import sys
import time
import re
import os

name = "minkcoin"

# gets the hash of a file; from https://stackoverflow.com/a/44873382
def hashFile(filename):
    h = hashlib.sha256()
    with open(filename, 'rb', buffering=0) as f:
        for b in iter(lambda : f.read(128*1024), b''):
            h.update(b)
    return h.hexdigest()

# given an array of bytes, return a hex reprenstation of it
def bytesToString(data):
    return binascii.hexlify(data)

# given a hex reprensetation, convert it to an array of bytes
def stringToBytes(hexstr):
    return binascii.a2b_hex(hexstr)

# Load the wallet keys from a filename
def loadWallet(filename):
    with open(filename, mode='rb') as file:
        keydata = file.read()
    privkey = rsa.PrivateKey.load_pkcs1(keydata)
    pubkey = rsa.PublicKey.load_pkcs1(keydata)
    return pubkey, privkey

# save the wallet to a file
def saveWallet(pubkey, privkey, filename):
    # Save the keys to a key format (outputs bytes)
    pubkeyBytes = pubkey.save_pkcs1(format='PEM')
    privkeyBytes = privkey.save_pkcs1(format='PEM')
    # Convert those bytes to strings to write to a file (gibberish, but a string...)
    pubkeyString = pubkeyBytes.decode('ascii')
    privkeyString = privkeyBytes.decode('ascii')
    # Write both keys to the wallet file
    with open(filename, 'w') as file:
        file.write(pubkeyString)
        file.write(privkeyString)
    return

def genesis():
    file = open("block_0.txt", "w") 
    file.write("No one in the world needs a mink coat but a mink.")
    file.close()
    print("Genesis block created in 'block_0.txt'")

def generate(wallet_name):
    (pub_key, priv_key) = rsa.newkeys(1024)
    try:
        saveWallet(pub_key, priv_key, wallet_name)
        print("New wallet generated in '" + wallet_name + "' with signature", address(wallet_name))
    except:
        print("Failed to generate wallet")

def address(wallet_name):
    with open(wallet_name, 'r') as file:
        contents = file.read()
    hash = hashlib.sha256(contents[31:221].encode("ascii")).hexdigest()
    return hash[0:16]

def fund(dest, amt, filename):
    caseID = "big_ben"
    try:
        file = open(filename, "w")
        file.write("From: " + caseID + "\n")
        file.write("To: " + dest + "\n")
        file.write("Amount: " + amt + "\n")
        date_time = time.ctime()
        file.write("Date: " + date_time)
        file.close()
        print("Funded wallet " + dest + " with " + amt + " minkcoins on " + date_time)
    except:
        print("Failed to fund wallet")

def transfer(wallet_name, dest, amt, filename):
    file = open(filename, "w")
    file.write("From: " + address(wallet_name) + "\n")
    file.write("To: " + dest + "\n")
    file.write("Amount: " + amt + "\n")
    date_time = time.ctime()
    file.write("Date: " + date_time + "\n")
    file.close()

    with open(filename, "r") as file:
        lines = file.readlines()
    content = "".join(lines).strip()

    print(content)

    pubkey, privkey = loadWallet(wallet_name)
    signature = rsa.sign(content.encode(), privkey, "SHA-256")

    file.close()

    print(type(signature))

    str_signature = str(bytesToString(signature), "UTF-8")

    print(str_signature)

    file = open(filename, "a")
    file.write("\n")
    file.write(str_signature)
    file.close()
    # Transferred 12 from alice.wallet.txt to d96b71971fbeec39 and the statement to '03-alice-to-bob.txt' on Tue Apr 02 23:09:00 EDT 2019
    print("Transferred " + amt + " minkcoin(s) from " + wallet_name + " to " + dest + " and the statement to " + filename + " on " + date_time)


def balance(wallet_addr):
    files = os.listdir()
    block_files = []
    bal = 0
    for f in files:
        if f.find("block_") != -1:
            block_files.append(f)
    
    if os.path.exists('mempool.txt'):
        block_files.append('mempool.txt')
    block_files.remove('block_0.txt')

    for f in block_files:
        with open(f, "r") as file:
            lines = file.readlines()
        if f != 'mempool.txt':
            lines = lines[2:-2]
        for line in lines:
            amt = int(re.search(r'\d+', line[16:]).group()) # * USED OTHER PLACES TOO * Found on https://stackoverflow.com/questions/32571348/getting-only-the-first-number-from-string-in-python
            if line.find(wallet_addr) > 0:
                bal += amt
            elif line.find(wallet_addr) == 0:
                bal -= amt
            else:
                continue
    
    return bal
    
    
def verify(wallet_name, trans_statement):
    pubkey, privkey = loadWallet(wallet_name)
    with open(trans_statement, "r") as file:
        lines = file.readlines()

    if len(lines) != 4:
        msg = lines[:len(lines) - 2]
        sig = lines[-1]
        message = "".join(msg).strip()

        sig = stringToBytes(sig)
        try: 
            rsa.verify(message.encode(), sig, pubkey)
        except:
            print("Cannot verify the signature")
        
    file = open("mempool.txt", "a")
    
    # e1f3ec14abcb45da transferred 12 to d96b71971fbeec39 on Tue Apr 02 23:09:02 EDT 2019
    payer = lines[0].split(" ").pop(1).strip()
    payee = lines[1][4:].strip()
    amt = lines[2][8:].strip()
    date = lines[3][6:].strip()
    if payer == "big_ben":
        file.write(payer + " transferred " + amt + " to " + payee + " on " + date + "\n")
        print("Any funding request (i.e., from big_ben) is considered valid; written to the mempool")
        return
    if int(amt) <= balance(address(wallet_name)):
        file.write(payer + " transferred " + amt + " to " + payee + " on " + date + "\n")
        # The transaction in file '04-bob-to-alice.txt' with wallet 'bob.wallet.txt' is valid, and was written to the mempool
        print("The transaction in file", trans_statement, "with wallet", wallet_name, "is valid, and was written to the mempool")
    else:
        print("Not enough balance to send funds")

def mine(difficulty):
    files = os.listdir()
    block_files = []
    cur_block = 0
    for f in files:
        if f.find("block_") != -1:
            num = int(re.search(r'\d+', f).group())
            if num > cur_block:
                cur_block = num
            block_files.append(f)
    
    # max_block = max(block_files)
    # cur_block = int(re.search(r'\d+', max_block).group())

    nonce = 0

    with open("mempool.txt", "r") as file:
        lines = file.readlines()

    file.close()
    os.remove("mempool.txt")

    file = open("block_" + str(cur_block + 1) + ".txt", "w")
    file.write(str(hashFile("block_" + str(cur_block) + ".txt")) + "\n") # Writes hash of last block
    file.write("\n")
    for line in lines:
        file.write(line)
    
    file.write("\n")
    file.write("nonce: " + str(nonce))
    file.close()

    target_not_found = True

    while(target_not_found):
        with open("block_" + str(cur_block + 1) + ".txt", 'r+') as f:
            content = f.read()
            content = re.sub('nonce: ' + str(nonce), 'nonce: ' + str(nonce + 1), content)
            f.seek(0)
            f.write(content)
            f.truncate()
        f.close()
        nonce += 1
        if str(hashFile("block_" + str(cur_block + 1) + ".txt"))[0:int(difficulty)] == "0" * int(difficulty):
            target_not_found = False
    
    # Mempool transactions moved to block_1.txt and mined with difficulty 2 and nonce 1029
    print("Mempool transactions moved to block_" + str(cur_block + 1) + ".txt and mined with difficulty " + str(difficulty) + " and nonce " + str(nonce))



def validate():
    files = os.listdir()
    block_files = []
    cur_block = 0
    for f in files:
        if f.find("block_") != -1:
            num = int(re.search(r'\d+', f).group())
            if num > cur_block:
                cur_block = num
            block_files.append(f)

    is_valid = True

    for i in range(0, cur_block):
        file = open("block_" + str(i + 1) + ".txt", "r")
        hash = file.readline().strip()
        if str(hashFile("block_" + str(i) + ".txt")) != hash:
            is_valid = False
    
    return is_valid




if sys.argv[1] == "name":
    print(name)
if sys.argv[1] == "genesis":
    genesis()
if sys.argv[1] == "generate" and sys.argv[2]:
    generate(sys.argv[2])
if sys.argv[1] == "address" and sys.argv[2]:
    print(address(sys.argv[2]))
if sys.argv[1] == "fund":
    fund(sys.argv[2], sys.argv[3], sys.argv[4])
if sys.argv[1] == "transfer":
    transfer(sys.argv[2], sys.argv[3], sys.argv[4], sys.argv[5])
if sys.argv[1] == "balance":
    print(balance(sys.argv[2]))
if sys.argv[1] == "verify":
    verify(sys.argv[2], sys.argv[3])
if sys.argv[1] == "mine":
    mine(sys.argv[2])
if sys.argv[1] == "validate":
    print(validate())
    