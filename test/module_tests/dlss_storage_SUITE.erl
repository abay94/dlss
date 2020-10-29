%%----------------------------------------------------------------
%% Copyright (c) 2020 Faceplate
%%
%% This file is provided to you under the Apache License,
%% Version 2.0 (the "License"); you may not use this file
%% except in compliance with the License.  You may obtain
%% a copy of the License at
%%
%%   http://www.apache.org/licenses/LICENSE-2.0
%%
%% Unless required by applicable law or agreed to in writing,
%% software distributed under the License is distributed on an
%% "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY
%% KIND, either express or implied.  See the License for the
%% specific language governing permissions and limitations
%% under the License.
%%----------------------------------------------------------------
-module(dlss_storage_SUITE).

-include("dlss_test.hrl").
-include("dlss.hrl").

%% API
-export([
  all/0,
  groups/0,
  init_per_testcase/2,
  end_per_testcase/2,
  init_per_group/2,
  end_per_group/2,
  init_per_suite/1,
  end_per_suite/1
]).

-export([
  test_service_api/1,
  test_storage_split/1,
  test_storage_children/1
]).


all()->
  [
    test_service_api,
    test_storage_split,
    test_storage_children
  ].

groups()->
  [].

%% Init system storages
init_per_suite(Config)->
  dlss_backend:init_backend(),
  Config.
end_per_suite(_Config)->
  dlss_backend:stop(),
  ok.

init_per_group(_,Config)->
  Config.

end_per_group(_,_Config)->
  ok.


init_per_testcase(_,Config)->
  Config.

end_per_testcase(_,_Config)->
  ok.

test_service_api(_Config)->

  ok=dlss_storage:add(storage1,disc),
  disc=dlss_storage:get_type(storage1),
  [storage1]=dlss_storage:get_storages(),
  [dlss_storage1_1]=dlss_storage:get_segments(),
  [dlss_storage1_1]=dlss_storage:get_segments(storage1),

  ?assertError(already_exists,dlss_storage:add(storage1,disc)),
  ?assertError(already_exists,dlss_storage:add(storage1,ramdisc)),


  ok=dlss_storage:add(storage2,ramdisc),
  ramdisc=dlss_storage:get_type(storage2),
  [storage1,storage2]=dlss_storage:get_storages(),
  [dlss_storage1_1,dlss_storage2_1]=dlss_storage:get_segments(),
  [dlss_storage2_1]=dlss_storage:get_segments(storage2),

  ok=dlss_storage:add(storage3,ram),
  ram=dlss_storage:get_type(storage3),
  [storage1,storage2,storage3]=dlss_storage:get_storages(),
  [dlss_storage1_1,dlss_storage2_1,dlss_storage3_1]=dlss_storage:get_segments(),
  [dlss_storage3_1]=dlss_storage:get_segments(storage3),

  dlss_storage:remove(storage2),
  [storage1,storage3]=dlss_storage:get_storages(),
  [dlss_storage1_1,dlss_storage3_1]=dlss_storage:get_segments(),

  dlss_storage:remove(storage1),
  [storage3]=dlss_storage:get_storages(),
  [dlss_storage3_1]=dlss_storage:get_segments(),

  dlss_storage:remove(storage3),
  []=dlss_storage:get_storages(),
  []=dlss_storage:get_segments(),

  ok.

test_storage_split(_Config)->

  ok=dlss_storage:add(storage1,disc),
  disc=dlss_storage:get_type(storage1),
  [storage1]=dlss_storage:get_storages(),
  [dlss_storage1_1]=dlss_storage:get_segments(storage1),

  ok = dlss_storage:spawn_segment(dlss_storage1_1),
  [dlss_storage1_1,dlss_storage1_2]=dlss_storage:get_segments(storage1),
  { ok, #{
    level := 1,
    key := '_'
  } } = dlss_storage:segment_params(dlss_storage1_2),

  ok = dlss_storage:spawn_segment(dlss_storage1_1,100),
  [dlss_storage1_1, dlss_storage1_2, dlss_storage1_3]=dlss_storage:get_segments(storage1),
  { ok, #{
    level := 1,
    key := 100
  } } = dlss_storage:segment_params(dlss_storage1_3),

  dlss_storage:remove(storage1),
  []=dlss_storage:get_storages(),
  []=dlss_storage:get_segments(),

  ok.

test_storage_children(_Config)->

  ok=dlss_storage:add(storage1,disc),
  disc=dlss_storage:get_type(storage1),
  [dlss_storage1_1]=dlss_storage:get_segments(storage1),

  ok = dlss_storage:spawn_segment(dlss_storage1_1),
  [dlss_storage1_1,dlss_storage1_2]=dlss_storage:get_segments(storage1),
  [{_,dlss_storage1_2}] = dlss_storage:get_children(dlss_storage1_1),

  ok = dlss_storage:spawn_segment(dlss_storage1_1,some_split_key),
  [dlss_storage1_1,dlss_storage1_2,dlss_storage1_3]=dlss_storage:get_segments(storage1),
  [{_,dlss_storage1_2},{_,dlss_storage1_3}] = dlss_storage:get_children(dlss_storage1_1),

  ok = dlss_storage:spawn_segment(dlss_storage1_2),
  [{_,dlss_storage1_4}] = dlss_storage:get_children(dlss_storage1_2),
  [
    {_,dlss_storage1_2},{_,dlss_storage1_4},
    {_,dlss_storage1_3}] = dlss_storage:get_children(dlss_storage1_1),
  [] = dlss_storage:get_children(dlss_storage1_3),

  ok = dlss_storage:spawn_segment(dlss_storage1_2,next_split_key),
  [{_,dlss_storage1_4},{_,dlss_storage1_5}] = dlss_storage:get_children(dlss_storage1_2),
  [
    {_,dlss_storage1_2},
    {_,dlss_storage1_4},{_,dlss_storage1_5},
    {_,dlss_storage1_3}
  ] = dlss_storage:get_children(dlss_storage1_1),
  [] = dlss_storage:get_children(dlss_storage1_3),

  ok = dlss_storage:spawn_segment(dlss_storage1_3),
  [{_,dlss_storage1_6}] = dlss_storage:get_children(dlss_storage1_3),
  [{_,dlss_storage1_4},{_,dlss_storage1_5}] = dlss_storage:get_children(dlss_storage1_2),
  [
    {_,dlss_storage1_2},
    {_,dlss_storage1_4},{_,dlss_storage1_5},
    {_,dlss_storage1_3},
    {_,dlss_storage1_6}
  ] = dlss_storage:get_children(dlss_storage1_1),

  ?assertError( { invalid_split_key, 22 }, dlss_storage:spawn_segment(dlss_storage1_3, 22) ),

  dlss_storage:remove(storage1),
  []=dlss_storage:get_storages(),
  []=dlss_storage:get_segments(),

  ok.



