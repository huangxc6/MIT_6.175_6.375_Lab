## Excercise 1

``` 
huangxc@Ubuntu:~/MIT_course/MIT_6.175_6.375_Lab/6.175_Project/unit_test/message-fifo-test$ ./simTb
Checkpoint 0
Checkpoint 1
Checkpoint 2
Checkpoint 3
Checkpoint 4
Checkpoint 5
Checkpoint 6
Checkpoint 7
Checkpoint 8
Checkpoint 9
Checkpoint 10
Checkpoint 11
Checkpoint 12
PASSED
```

## Exercise 2

```
huangxc@Ubuntu:~/MIT_course/MIT_6.175_6.375_Lab/6.175_Project/unit_test/message-router-test$ ./simTb
Checkpoint 0
Checkpoint 1
Checkpoint 2
Checkpoint 3
Checkpoint 4
Checkpoint 5
Checkpoint 6
Checkpoint 7
Checkpoint 8
Checkpoint 9
Checkpoint 10
Checkpoint 11
Checkpoint 12
PASSED
```

## Exercise3

```
./simTb
Load mini test 1: load miss
  Requesting load to cache
  Looking for upgrade to S request to main memory
  Found upgrade to S request, sending upgrade to S response
  Looking for response for load
Correct : got response         10
  Found response, test passed

Load mini test 2: load hit
  Requesting load to cache
  Looking for response for load
Correct : got response         20
  Found response, test passed

Store mini test 1: store miss (S -> M)
  Requesting store to cache
  Looking for upgrade to M request to main memory
  Found upgrade to M request, sending upgrade to M response
  Sending downgrade to I request to check data
  Looking for downgrade response
  Found correct data, test passed

Store mini test 2: store miss (I -> M)
  Requesting store to cache
  Looking for upgrade to M request to main memory
  Found upgrade to M request, sending upgrade to M response
  Data will be checked in the next test

Store mini test 3: store hit
  Requesting store to cache
  Sending downgrade to I request to check data
  Looking for downgrade response
  Data matches, test passed

Downgrade mini test 4: downgrade req interleaved with upgrade req
  Requesting load to cache
  Looking for upgrade to S request to main memory
  Found upgrade to S request, sending upgrade to S response
  Looking for response for load
Correct : got response        999
  Found correct data, requesting store to cache
  Sending dwongrade to I request to cache
  Looking for downgrade response
  Found downgrade to I respondse, looking for upgrade request
  Found upgrade to M request, sending upgrade to M response
  Sending downgrade to S request to check data
  Looking for downgrade response
  Data matches, test passed

Replacement mini test 5: replacement and rule 7
  Requesting load to cache line (0,2)
  Looking for upgrade request
  Found upgrade to S request, sending upgrade to S response
  Looking for response for load
Correct : got response         77
  Found correct data, requesting store to cache line (1,2), evicting (0,2) first
  Looking for downgrade response
  Cache send downgrade to I response, sending downgrade request to cache again, cache should ignore it
  Make sure the cache didn't send another response
  No downgrade response sent, looking for upgrade request
  Found upgrade to M request, sending upgrade to M response
  Requesting store to cache line (2,2), evicting (1,2) first
  Looking for downgrade response
  Cache send downgrade to I response, sending downgrade request to cache again, cache should ignore it
  Make sure the cache didn't send another response
  No downgrade response sent, looking for upgrade request
  Found upgrade to S request, send upgrade to S response to cache
  Looking for response for load
Correct : got response         99
  Found correct data, test passed
```
