#!/usr/bin/env python3

import os
import sqlite3

def identify_ints(v):
    for x in v:
        try:
            yield int(x)
        except:
            pass

def main():
    run_ids = [
        x for x in sorted(identify_ints(os.listdir('runs')))
        if os.path.exists(os.path.join('runs', '{}'.format(x), 'output.sqlite'))
    ]
    
    with sqlite3.connect('db.sqlite') as db:
        print(run_ids[0])
        create_output_table(db, os.path.join('runs', '{}'.format(run_ids[0]), 'output.sqlite'))
        
        for run_id in run_ids[1:]:
            print(run_id)
            insert_from_output_table(db, os.path.join('runs', '{}'.format(run_id), 'output.sqlite'))

def create_output_table(db, src_filename):
    db.execute('ATTACH DATABASE "{}" AS src'.format(src_filename))
    db.execute('CREATE TABLE output AS SELECT * FROM src.output')
    db.commit()
    db.execute('DETACH DATABASE src')
    db.commit()

def insert_from_output_table(db, src_filename):
    db.execute('ATTACH DATABASE "{}" AS src'.format(src_filename))
    db.execute('INSERT INTO output SELECT * FROM src.output')
    db.commit()
    db.execute('DETACH DATABASE src')
    db.commit()

if __name__ == '__main__':
    main()
