import sys
import time
import re
import os
import random

userid = "bwg9sbe"

def finite_field_add(a, b, p):
    return (a + b) % p

def finite_field_sub(a, b, p):
    return (a - b) % p

def finite_field_mul(a, b, p):
    return (a * b) % p

def finite_field_div(a, b, p):
    return (a * pow(b, p - 2, p)) % p

def finite_field_exp(a, b, p):
    return pow(a, b, p)

def finite_field_add_inv(a, p):
    # Additive Inverse
    return finite_field_sub(0, a, p)

def finite_field_mult_inv(a, p):
    # Multiplicative Inverse
    return pow(a, p - 2, p)

def elliptic_point_double(P, p):
    # Double a point on an elliptic curve
    x = P[0]
    y = P[1]

    # Find slope
    m = (3 * x * x) * finite_field_mult_inv(2 * y, p)
    x_3 = finite_field_add(finite_field_mul(m, m, p), -2 * x, p)
    y_3 = finite_field_sub(finite_field_mul(m, x - x_3, p), y, p)
    return [x_3, y_3]


def elliptic_point_add(P, Q, p):
    # Addition of two points on an elliptic curve
    x_1 = P[0]
    y_1 = P[1]
    x_2 = Q[0]
    y_2 = Q[1]

    if x_1 == x_2 and y_1 != y_2:
        return [-1, -1]

    # Find slope
    m = (y_2 - y_1) * finite_field_mult_inv(x_2 - x_1, p)
    x_3 = finite_field_add(finite_field_mul(m, m, p), -x_1 - x_2, p)
    y_3 = finite_field_sub(finite_field_mul(m, x_1 - x_3, p), y_1, p)
    return [x_3, y_3]


def elliptic_point_multiply(P, n, p):
    # Multiply a point on an elliptic curve by an integer
    if n == 0:
        return [0, 0]
    elif n == 1:
        return P
    elif n % 2 == 0:
        return elliptic_point_double(elliptic_point_multiply(P, n // 2, p), p)
    else:
        return elliptic_point_add(elliptic_point_multiply(P, n - 1, p), P, p)


def genkey(p, o, g_x, g_y):
    # Generate private key
    d = random.randint(1, o - 1)

    # Generate public key
    Q = elliptic_point_multiply([g_x, g_y], d, p)
    return [d, Q]


def sign(p, o, g_x, g_y, d, h):
    # Sign a message
    k = random.randint(1, o - 1)
    r = elliptic_point_multiply([g_x, g_y], k, p)
    s = (finite_field_mul(finite_field_mult_inv(k, o), h + (r[0] * d), o)) % o
    return [r[0], s]


def verify(p, o, g_x, g_y, q_x, q_y, r, s, h):
    # Verify a signature
    w = finite_field_mult_inv(s, o)
    u_1 = finite_field_mul(h, w, o)
    u_2 = finite_field_mul(r, w, o)
    u_3 = elliptic_point_multiply([g_x, g_y], u_1, p)
    u_4 = elliptic_point_multiply([q_x, q_y], u_2, p)
    P = elliptic_point_add(u_3, u_4, p)
    return r == P[0]


# print(elliptic_point_multiply((42, 7), 4, 43))
# print(elliptic_point_add((21,25), (25,25), 43))
# print(elliptic_point_add((21,18), (42,36), 43))

# Add command line arguments to list
args = sys.argv

if sys.argv[1] == "userid":
    print(userid)
if sys.argv[1] == "genkey":
    output = genkey(int(args[2]), int(args[3]), int(args[4]), int(args[5]))
    print(output[0])
    print(output[1][0])
    print(output[1][1])
if sys.argv[1] == "sign":
    output = sign(int(args[2]), int(args[3]), int(args[4]), int(args[5]), int(args[6]), int(args[7]))
    print(output[0])
    print(output[1])
if sys.argv[1] == "verify":
    output = verify(int(args[2]), int(args[3]), int(args[4]), int(args[5]), int(args[6]), int(args[7]), int(args[8]), int(args[9]), int(args[10]))
    print(output)
