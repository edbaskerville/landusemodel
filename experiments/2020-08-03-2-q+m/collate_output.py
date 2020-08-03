#!/usr/bin/env python3

import os
import sys
import csv
import sqlite3

os.chdir(os.path.dirname(__file__))

def main():
  assert(os.path.exists('db.sqlite'))
  with sqlite3.connect('db.sqlite', isolation_level = None) as db:
    db.execute('''
      CREATE TABLE output (
        run_id INTEGER,
        time REAL,
        H INTEGER, H_lifetime_avg REAL,
        A INTEGER, A_lifetime_avg REAL,
        F INTEGER, F_lifetime_avg REAL,
        D INTEGER, D_lifetime_avg REAL,
        betaMean REAL, betaSD REAL,
        betaMin REAL, betaMax REAL,
        beta025 REAL, beta050 REAL, beta100 REAL, beta250 REAL, beta500 REAL, beta750 REAL, beta900 REAL, beta950 REAL, beta975 REAL
      );
    ''')
    
    for run_id in sorted(run_ids()):
      print('Processing {}...'.format(run_id))
    
      db.execute('BEGIN TRANSACTION')
      with open(csv_path(run_id)) as cf:
        cr = csv.DictReader(cf)
        for row in cr:
          insert_row(db, run_id, row)
      db.execute('COMMIT')
  
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

def csv_path(run_id):
  return os.path.join('runs', str(run_id), 'output.csv')

def run_ids():
  for run_id_str in os.listdir('runs'):
    if os.path.exists(csv_path(run_id_str)):
      yield int(run_id_str)

if __name__ == '__main__':
  main()
