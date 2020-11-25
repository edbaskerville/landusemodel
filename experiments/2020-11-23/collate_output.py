#!/usr/bin/env python3

import os
import sys
import sqlite3

def main():
    assert(os.path.exists('db.sqlite'))
    with sqlite3.connect('db.sqlite', isolation_level = None) as db:
        db.execute('BEGIN TRANSACTION')
        db.execute('''
          CREATE TABLE output (
            run_id INTEGER,
            time REAL,
            H INTEGER, H_lifetime_avg REAL,
            A INTEGER, A_lifetime_avg REAL,
            F INTEGER, F_lifetime_avg REAL,
            D INTEGER, D_lifetime_avg REAL,
            beta_mean REAL, beta_sd REAL,
            beta_min REAL, beta_max REAL,
            beta_025 REAL, beta_050 REAL, beta_100 REAL, beta_250 REAL, beta_500 REAL, beta_750 REAL, beta_900 REAL, beta_950 REAL, beta_975 REAL
          );
        ''')
        db.execute('COMMIT')
        
        for run_id in sorted(run_ids()):
            print('Processing {}...'.format(run_id))
            
            db.execute('ATTACH DATABASE "{}" AS src'.format(os.path.join('runs', str(run_id), 'output.sqlite')))
            db.execute('BEGIN TRANSACTION')
            
            db.execute('INSERT INTO output SELECT {}, * FROM src.output'.format(run_id))
            
            db.execute('COMMIT')
            db.execute('DETACH DATABASE src')
        
        db.execute('BEGIN TRANSACTION')
        db.execute('CREATE INDEX output_index ON output (run_id);')
        db.execute('COMMIT')

def insert_row(db, run_id, row):
    db.execute(
        'INSERT INTO output VALUES (?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?)',
        [
            run_id,
            parse_float(row['time']),
            parse_int(row['H']), parse_float(row['H_lifetime_avg']),
            parse_int(row['A']), parse_float(row['A_lifetime_avg']),
            parse_int(row['F']), parse_float(row['F_lifetime_avg']),
            parse_int(row['D']), parse_float(row['D_lifetime_avg']),
            parse_float(row['betaMean']), parse_float(row['betaSD']),
            parse_float(row['betaMin']), parse_float(row['betaMax']),
            parse_float(row['beta025']),
            parse_float(row['beta050']),
            parse_float(row['beta100']),
            parse_float(row['beta250']),
            parse_float(row['beta500']),
            parse_float(row['beta750']),
            parse_float(row['beta900']),
            parse_float(row['beta950']),
            parse_float(row['beta975']),
        ]
    )

def parse_float(s):
    if s == '':
        return None
    else:
        return float(s)

def parse_int(s):
    if s == '':
        return None
    else:
        return int(s)

def db_path(run_id):
    return os.path.join('runs', str(run_id), 'output.sqlite')

def run_ids():
    for run_id_str in os.listdir('runs'):
        if os.path.exists(db_path(run_id_str)):
            yield int(run_id_str)

if __name__ == '__main__':
    main()
