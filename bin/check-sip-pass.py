import sys
import string
import hashlib


def checkAuthorization(username, realm, uri, password, nonce, method="REGISTER"):
    a1="%s:%s:%s" % (username, realm, password)
    a2="%s:%s" % (method, uri)
    ha1 = hashlib.md5(a1).hexdigest()
    ha2 = hashlib.md5(a2).hexdigest()
    b = "%s:%s:%s" % (ha1,nonce,ha2)
    expected = hashlib.md5(b).hexdigest()
    return expected

if __name__ == '__main__':
    import optparse
    
    usage = """%prog -u <username> -r <realm> -U <URI> -p <password> -n <nonce> [-m METHOD] [-h]
    
    This scripts returns the authorization header calculated whti MD5 hash
    """
    
    opt = optparse.OptionParser(usage=usage)
    opt.add_option('-u', dest="username", default=None, help="SIP Username")
    opt.add_option('-r', dest="realm", default=None, help="SIP Realm")
    opt.add_option('-U', dest="uri", default=None, help="SIP URI")
    opt.add_option('-p', dest="password", default=None, help="SIP Password")
    opt.add_option('-n', dest="nonce", default=None, help="SIP Nonce")
    opt.add_option('-m', dest="method", default="REGISTER", help="SIP Method")

    options, args = opt.parse_args(sys.argv[1:])

    if options.username == None:
        opt.print_usage()
        sys.exit(-1)
    if options.username == None:
        opt.print_usage()
        sys.exit(-1)
    if options.realm == None:
        opt.print_usage()
        sys.exit(-1)
    if options.uri == None:
        opt.print_usage()
        sys.exit(-1)
    if options.password == None:
        opt.print_usage()
        sys.exit(-1)
    if options.nonce == None:
        opt.print_usage()
        sys.exit(-1)
    if options.method == None:
        opt.print_usage()
        sys.exit(-1)

    auth = checkAuthorization(
                        options.username,
                        options.realm,
                        options.uri,
                        options.password,
                        options.nonce,
                        options.method)

    print(auth)
