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

-module(dlss_schema_scanner).

-include("dlss.hrl").

-behaviour(gen_server).

%%=================================================================
%%	API
%%=================================================================
-export([
  start_link/0
]).

%%=================================================================
%%	OTP
%%=================================================================
-export([
  init/1,
  handle_call/3,
  handle_cast/2,
  handle_info/2,
  terminate/2,
  code_change/3
]).

-define(DEFAULT_SCAN_CYCLE,5000).

-record(state,{ cycle, segments }).

%%=================================================================
%%	API
%%=================================================================
start_link()->
  gen_server:start_link({local,?MODULE}, ?MODULE,[], []).

%%=================================================================
%%	OTP
%%=================================================================
init([])->

  ?LOGINFO("starting schema scanner ~p",[self()]),

  Cycle=?ENV(segment_scan_cycle, ?DEFAULT_SCAN_CYCLE),

  % Enter the loop
  self()!loop,

  {ok,#state{
    cycle = Cycle,
    segments = []
  }}.

handle_call(Request, From, State) ->
  ?LOGWARNING("schema scanner got an unexpected call resquest ~p from ~p",[Request,From]),
  {noreply,State}.


handle_cast(Request,State)->
  ?LOGWARNING("schema scanner got an unexpected cast resquest ~p",[Request]),
  {noreply,State}.

%%============================================================================
%%	The loop
%%============================================================================
handle_info(loop,#state{
  cycle = Cycle,
  segments = Started
}=State)->

  % Keep the loop
  {ok,_}=timer:send_after(Cycle,loop),

  % Scanning procedure
  Started1=
    try
      scan_segments(Started)
    catch
        _:Error:Stack->
          ?LOGERROR("schema scanner error ~p, stack ~p",[Error,Stack]),
          Started
    end,

  {noreply,State#state{segments = Started1}}.

terminate(Reason,_State)->
  ?LOGINFO("terminating schema scanner reason ~p",[Reason]),
  ok.

code_change(_OldVsn, State, _Extra) ->
  {ok, State}.

%%============================================================================
%%	The loop
%%============================================================================
scan_segments(Started)->
  ?LOGDEBUG("start schema scanning"),

  % The service checks a schema on segments hosted by this node.
  % Each hosted segment must have a serving process that is responsible
  % for its balancing

  Segments = get_supervised_segemnts( node() ),

  % Start new segments
  [ dlss_segment:start(S) || S <- Segments -- Started ],

  % Stop no longer supervised segments
  [ dlss_segment:stop(S) || S <- Started -- Segments ],

  Segments.

get_supervised_segemnts(Node)->
  % Get list of attached nodes
  ReadyNodes = dlss_node:get_ready_nodes(),
  All = dlss_storage:get_segments(),
  % Filter segment for which the Node is the master
  Filter=
    fun(S)->
      #{ nodes := Nodes } = dlss_segment:get_info(S),
      case Nodes -- ( Nodes -- ReadyNodes ) of
        [ Node|_ ] ->
          % If the Node is the first node in the list of hosting nodes for the segment
          % then the Node is the master and should supervise the segment
          true;
        _ -> false
      end
    end,
  [ S || S <- All, Filter(S) ].
