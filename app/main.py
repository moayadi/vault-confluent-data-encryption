from mimesis.enums import Gender, PortRange
from mimesis.locales import Locale
from mimesis.schema import Field, Schema
import json
import time
import os

num_of_runs = int(os.environ["NUM_OF_RUNS"])
path_to_file = os.environ["PATH_TO_LOG"]



_ = Field(locale=Locale.EN, seed='test')
schema = Schema(schema=lambda: {
    "uid": _("uuid"),
    "name": _("text.word"),
    "version": _("version", pre_release=True),
    "timestamp": _("timestamp", posix=False),
    "owner": {
        "full_name": _("full_name", gender=Gender.FEMALE),
        "email": _("person.email", domains=["test.com"], key=str.lower),
        "age": _("person.age", minimum=18, maximum=45),
        "NRIC": _("person.identifier", mask='@#######@'),
        "telephone": _("person.telephone", mask='+65-####-####'),
        "postal_code": _("person.identifier", mask='######'),
        "username":  _("person.username", mask='l_d', drange=(1900, 2021))
    },

    "connection_details": {
        "ip_address": _("internet.ip_v4_with_port", port_range=PortRange.EPHEMERAL)
    },
    "choices": {
        "places_of_interest": _("choice",items=['museum','resturant','stadium','park','home'])
    },

})


def write_to_file(data:[]):
    # try to create file first if doesn't exist
    if not os.path.exists(path_to_file):
        open(path_to_file, 'w').close()

    with open(path_to_file,'a') as f:
        for i in data:
            f.write(json.dumps(i)+'\n')
            print("written to log")
            time.sleep(.1)

    f.close()

if __name__ == '__main__':
    while True:
        data = schema.create(iterations=num_of_runs)
        print(data)
        print("writing to log \n")
        write_to_file(data=data)

