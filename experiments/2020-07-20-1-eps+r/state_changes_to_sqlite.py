#!/usr/bin/env python3

import csv
import sqlite3

def main():
    with sqlite3.connect('state_changes.sqlite') as db:
        db.execute('''CREATE TABLE state_changes (
            time REAL,
            row INTEGER,
            col INTEGER,
            P INTEGER,
            beta REAL
        );''')
        
        with open('state_changes.csv') as f:
            rdr = csv.DictReader(f)
            for row in rdr:
                db.execute(
                    'INSERT INTO state_changes VALUES (?,?,?,?,?)',
                    (
                        float(row['time']),
                        int(row['row']),
                        int(row['col']),
                        int(row['P']),
                        None if row['beta'] == '' else float(row['beta']),
                    )
                )
        
        db.execute('CREATE INDEX time_index ON state_changes (time)')

if __name__ == '__main__':
    main()
