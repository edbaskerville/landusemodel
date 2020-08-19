#!/usr/bin/env python3

import os
import sys
import sqlite3
import json
import random
from collections import OrderedDict

JOB_SCRIPT_TEMPLATE = '''#!/bin/bash

#SBATCH --job-name=LUM-{run_id}

#SBATCH --account=pi-pascualmm
#SBATCH --partition=broadwl

#SBATCH --time=6:00:00
#SBATCH --nodes=1
#SBATCH --ntasks-per-node=1
#SBATCH --mem-per-cpu=2000

#SBATCH --chdir={run_dir}
#SBATCH --output=stdout.txt
#SBATCH --error=stderr.txt

module purge

module load parallel
module load java/11.0.1

./run.sh
'''

def main():
    if not os.path.exists('db.sqlite'):
        print('No run DB')
        sys.exit(1)
    
    with sqlite3.connect('db.sqlite') as db:
        # Identify failed runs
        failed_run_ids = [
            run_id for run_id, in db.execute('SELECT run_id FROM runs')
            if not os.path.exists(os.path.join('runs', '{}'.format(run_id), 'output.csv'))
        ]
        print(failed_run_ids)
    
        # Check tmp dirs and config files
        for run_id in failed_run_ids:
            if os.path.exists(tmp_dir(run_id)):
                print('{} needs to be removed'.format(tmp_dir(run_id)))
                sys.exit(1)
            
            if not os.path.exists(config_path(run_id)):
                print('{} does not exist'.format(config_path(run_id)))
                sys.exit(1)
        
        # Generate new random seeds
        for run_id in failed_run_ids:
            rng_seed = random.randint(1, 2**31 - 1)
            db.execute(
                'UPDATE runs SET randomSeed = ? WHERE run_id = ?',
                (rng_seed, run_id,)
            )
            
            config = load_config(run_id)
            config['randomSeed'] = rng_seed
            dump_config(run_id, config)
            
        # Create a job script for each failed run
        os.mkdir('jobs_redo')
        with open('submit_redo.sh', 'w') as submit_file:
            submit_file.write('#!/bin/bash\n\n')
            for run_id in failed_run_ids:
                sbatch_filename = os.path.join('jobs_redo', '{}.sbatch'.format(run_id))
                with open(sbatch_filename, 'w') as sbatch_file:
                    sbatch_file.write(JOB_SCRIPT_TEMPLATE.format(
                        run_id = run_id,
                        run_dir = os.path.abspath(run_dir(run_id))
                    ))
                submit_file.write('sbatch {}\n'.format(os.path.abspath(sbatch_filename)))
        os.system('chmod +x submit_redo.sh')
    

def run_dir(run_id):
    return os.path.join('runs', '{}'.format(run_id))

def config_path(run_id):
    return os.path.join(run_dir(run_id), 'config.json')

def load_config(run_id):
    with open(config_path(run_id)) as f:
        return json.load(f, object_pairs_hook = OrderedDict)

def dump_config(run_id, config):
    with open(config_path(run_id), 'w') as f:
        json.dump(config, f, indent = 2)

def tmp_dir(run_id):
    return os.path.join(run_dir(run_id), 'tmp')

if __name__ == '__main__':
    main()
