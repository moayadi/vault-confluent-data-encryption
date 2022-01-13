import base64
from confluent_kafka import Consumer
from confluent_kafka import Producer
import hvac
import sys
from benedict import benedict
import socket
import os
import logging
import json

vault_url = os.environ["VAULT_ADDR"]
vault_token = os.environ["VAULT_TOKEN"]
kafka_group = os.environ["KAFKA_GROUP"]
egress_topic = os.environ["EGRESS_TOPIC"]
ingress_topic = os.environ["INGRESS_TOPIC"]
secrets_path = os.environ["SECRETS_PATH"]
configs_path = os.environ["CONFIGS_PATH"]
log_level = os.environ.get('LOGLEVEL', 'WARNING').upper()

logger = logging.getLogger('transformer')
logging.basicConfig(level=log_level)

def organize_keys(keys: [], paths: []):
    batch_aes = []
    batch_aes_converge = []
    transform = []

    for key in paths:
        for k in keys:
            if k['key'] == key:
                if k['method'] == "aes":
                    encoded = base64ify(d[key])
                    batch_aes.append({'key': key, 'plaintext': encoded})
                if k['method'] == "aes-converge":
                    encoded = base64ify(d[key])
                    context = base64ify(convergent_context_id)
                    batch_aes_converge.append({'key': key, 'context': context, 'plaintext': encoded})
                if k['method'] == "transform":
                    encoded = base64ify(d[key])
                    transform.append({'key': key, 'value': d[key], 'transformation': k['transformation']})
                    logger.debug(transform)

    return {
        'batch-aes': batch_aes,
        'batch-aes-converge': batch_aes_converge,
        'transform': transform
    }


def base64ify(bytes_or_str):
    """Helper method to perform base64 encoding across Python 2.7 and Python 3.X"""
    if sys.version_info[0] >= 3 and isinstance(bytes_or_str, str):
        input_bytes = bytes_or_str.encode('utf8')
    else:
        input_bytes = bytes_or_str

    output_bytes = base64.urlsafe_b64encode(input_bytes)
    if sys.version_info[0] >= 3:
        return output_bytes.decode('ascii')
    else:
        return output_bytes


def aes_encrypt(client: hvac, key_name: str, to_encrypt: str):
    cipher = hvac.v1.api.secrets_engines.Transit.encrypt_data(self=client, mount_point=transit_mount_point,
                                                              plaintext=to_encrypt,
                                                              name=key_name)
    return cipher


def encrypt_batch(client: hvac, to_encrypt: []):
    response = []

    # transform list for batch_input, removing the 'key' key.  batch_input only requires a list of 'plaintext'
    for k, v in to_encrypt.items():
        logger.debug("encryption type: " + k)
        logger.debug(v)
        if k == "batch-aes":
            plaintext = []
            keys = []
            if v:
                for i in v:
                    keys.append(i['key'])
                    i.pop('key')
                    plaintext.append(i)
                # perform encryption
                ciphertext = hvac.v1.api.secrets_engines.Transit.encrypt_data(self=client,
                                                                              mount_point=transit_mount_point,
                                                                              plaintext="",
                                                                              name=transit_key_name,
                                                                              batch_input=plaintext)
                for i in range(len(keys)):
                    response.append(
                        {'key': keys[i], 'ciphertext': ciphertext['data']['batch_results'][i]['ciphertext']})

        elif k == "batch-aes-converge":
            plaintext = []
            keys = []
            if v:
                for i in v:
                    keys.append(i['key'])
                    i.pop('key')
                    plaintext.append(i)
                # perform encryption
                ciphertext = hvac.v1.api.secrets_engines.Transit.encrypt_data(self=client,
                                                                              mount_point=transit_mount_point,
                                                                              plaintext="",
                                                                              name=convergent_key_name,
                                                                              batch_input=plaintext)
                for i in range(len(keys)):
                    response.append(
                        {'key': keys[i], 'ciphertext': ciphertext['data']['batch_results'][i]['ciphertext']})

        elif k == "transform":
            plaintext = []
            keys = []
            if v:
                for i in v:
                    keys.append(i['key'])
                    i.pop('key')
                    plaintext.append(i)

                # perform encryption
                ciphertext = hvac.v1.api.secrets_engines.Transform.encode(self=client,
                                                                          mount_point=transform_mount_point,
                                                                          role_name=transform_role_name,
                                                                          batch_input=plaintext)
                for i in range(len(keys)):
                    response.append(
                        {'key': keys[i], 'ciphertext': ciphertext['data']['batch_results'][i]['encoded_value']})

    return response


def get_confluent_creds(client: hvac):
    creds = hvac.Client.read(self=client, path=secrets_path)
    return creds['data']['data']


def get_encryption_config(client: hvac):
    config = hvac.Client.read(self=client, path=configs_path)
    return config['data']['data']


if __name__ == '__main__':

    client = hvac.Client(url=vault_url, token=vault_token)

    secrets = get_confluent_creds(client)
    configs = get_encryption_config(client)

    keys_of_interest = configs['keys_of_interest']
    transform_mount_point = configs['transform_mount']
    transform_role_name = configs['transform_role_name']
    transit_mount_point = configs['transit_mount']
    transit_key_name = configs['transit_key_name']
    convergent_key_name = configs['convergent_key_name']
    convergent_context_id = secrets['convergent_context_id']
    sasl_username = secrets['client_id']
    sasl_password = secrets['client_secret']
    sasl_connection = secrets['connection_string']

    c = Consumer({
        ''
        'bootstrap.servers': sasl_connection,
        'security.protocol': 'SASL_SSL',
        'sasl.mechanism': 'PLAIN',
        'sasl.username': sasl_username,
        'sasl.password': sasl_password,
        'group.id': kafka_group,
        'auto.offset.reset': 'earliest'
    })

    p = Producer({
        'bootstrap.servers': sasl_connection,
        'security.protocol': 'SASL_SSL',
        'sasl.mechanism': 'PLAIN',
        'sasl.username': sasl_username,
        'sasl.password': sasl_password,
        'client.id': socket.gethostname()

    })

    c.subscribe([ingress_topic])

    while True:
        msg = c.poll(1.0)

        if msg is None:
            continue
        if msg.error():
            print("Consumer error: {}".format(msg.error()))
            continue

        ingress_msg = json.loads(msg.value().decode('utf-8'))

        logger.debug("message to process: " + msg.value().decode('utf-8'))

        d = benedict(ingress_msg)

        ingress_key_paths = d.keypaths(indexes=False)

        sorted_keys = organize_keys(keys=keys_of_interest, paths=ingress_key_paths)

        cipher = encrypt_batch(client=client, to_encrypt=sorted_keys)

        for key in cipher:
            d[key['key']] = key['ciphertext']

        egress_msg_json = json.dumps(d)

        p.produce(topic=egress_topic, value=egress_msg_json)

        logger.debug("message sent to egress topic: " + egress_msg_json)


    c.close()
