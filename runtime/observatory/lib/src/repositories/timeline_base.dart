// Copyright (c) 2019, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file

import 'dart:async';
import 'package:observatory/sample_profile.dart';
import 'package:observatory/models.dart' as M;
import 'package:observatory/service.dart' as S;

class TimelineRepositoryBase {
  static const _kStackFrames = 'stackFrames';
  static const _kTraceEvents = 'traceEvents';
  static const kTimeOriginMicros = 'timeOriginMicros';
  static const kTimeExtentMicros = 'timeExtentMicros';

  Future<void> _formatSamples(
      M.Isolate isolate, Map traceObject, S.ServiceMap cpuSamples) async {
    const kRootFrameId = 0;
    final profile = SampleProfile();
    await profile.load(isolate as S.ServiceObjectOwner, cpuSamples);
    final trie = profile.loadFunctionTree(M.ProfileTreeDirection.inclusive);
    final root = trie.root;
    int nextId = kRootFrameId;
    processFrame(FunctionCallTreeNode current, FunctionCallTreeNode parent) {
      int id = nextId;
      ++nextId;
      current.frameId = id;
      // Skip the root.
      if (id != kRootFrameId) {
        final function = current.profileFunction.function;
        final key = '${isolate.id}-$id';
        traceObject[_kStackFrames][key] = {
          'category': 'Dart',
          'name': function.qualifiedName,
          'resolvedUrl': current.profileFunction.resolvedUrl,
          if (parent != null && parent.frameId != kRootFrameId)
            'parent': '${isolate.id}-${parent.frameId}',
        };
      }

      for (final child in current.children) {
        processFrame(child, current);
      }
    }

    processFrame(root, null);

    for (final sample in profile.samples) {
      FunctionCallTreeNode trie = sample[SampleProfile.kTimelineFunctionTrie];

      if (trie.frameId != kRootFrameId) {
        traceObject[_kTraceEvents].add({
          'ph': 'P', // kind = sample event
          'name': '', // Blank to keep about:tracing happy
          'pid': profile.pid,
          'tid': sample['tid'],
          'ts': sample['timestamp'],
          'cat': 'Dart',
          'sf': '${isolate.id}-${trie.frameId}',
        });
      }
    }
  }

  Future<Map> getCpuProfileTimeline(M.VMRef ref,
      {int timeOriginMicros, int timeExtentMicros}) async {
    final S.VM vm = ref as S.VM;
    final sampleRequests = <Future>[];

    for (final isolate in vm.isolates) {
      sampleRequests.add(vm.invokeRpc('getCpuSamples', {
        'isolateId': isolate.id,
        if (timeOriginMicros != null) kTimeOriginMicros: timeOriginMicros,
        if (timeExtentMicros != null) kTimeExtentMicros: timeExtentMicros,
      }));
    }

    final completed = await Future.wait(sampleRequests);
    final traceObject = <String, dynamic>{
      _kStackFrames: {},
      _kTraceEvents: [],
    };
    for (int i = 0; i < vm.isolates.length; ++i) {
      await _formatSamples(vm.isolates[i], traceObject, completed[i]);
    }
    return traceObject;
  }

  Future<Map> getTimeline(M.VMRef ref) async {
    final S.VM vm = ref as S.VM;
    final S.ServiceMap vmTimelineResponse =
        await vm.invokeRpc('getVMTimeline', {});
    final timeOriginMicros = vmTimelineResponse[kTimeOriginMicros];
    final timeExtentMicros = vmTimelineResponse[kTimeExtentMicros];
    final traceObject = await getCpuProfileTimeline(
      vm,
      timeOriginMicros: timeOriginMicros,
      timeExtentMicros: timeExtentMicros,
    );
    traceObject[_kTraceEvents].addAll(vmTimelineResponse[_kTraceEvents]);
    return traceObject;
  }
}
