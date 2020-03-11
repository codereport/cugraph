# Copyright (c) 2019, NVIDIA CORPORATION.
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

# cython: profile=False
# distutils: language = c++
# cython: embedsignature = True
# cython: language_level = 3

from cugraph.layout.force_atlas cimport *
from cugraph.structure.graph cimport *
from cugraph.structure import graph_wrapper
from cugraph.utilities.column_utils cimport *
from libcpp cimport bool
from libc.stdint cimport uintptr_t
from libc.stdlib cimport calloc, malloc, free

import cudf
import cudf._lib as libcudf
import rmm
import numpy as np


def force_atlas(input_graph,
                max_iter=1000,
                gravity=1.0,
                scaling_ratio=1.0,
                barnes_hut_theta=0.5,
                edge_weight_influence=1.0,
                lin_log_mode=False,
                prevent_overlapping=False)

    """
    Call force_atlas
    """
    cdef uintptr_t graph = graph_wrapper.allocate_cpp_graph()
    cdef Graph * g = <Graph*> graph

    if input_graph.adjlist:
        [offsets, indices] = graph_wrapper.datatype_cast([input_graph.adjlist.offsets, input_graph.adjlist.indices], [np.int32])
        [weights] = graph_wrapper.datatype_cast([input_graph.adjlist.weights], [np.float32, np.float64])
        graph_wrapper.add_adj_list(graph, offsets, indices, weights)
    else:
        [src, dst] = graph_wrapper.datatype_cast([input_graph.edgelist.edgelist_df['src'], input_graph.edgelist.edgelist_df['dst']], [np.int32])
        if input_graph.edgelist.weights:
            [weights] = graph_wrapper.datatype_cast([input_graph.edgelist.edgelist_df['weights']], [np.float32, np.float64])
            graph_wrapper.add_edge_list(graph, src, dst, weights)
        else:
            graph_wrapper.add_edge_list(graph, src, dst)
        add_adj_list(g)
        offsets, indices, values = graph_wrapper.get_adj_list(graph)
        input_graph.adjlist = input_graph.AdjList(offsets, indices, values)

        # we should add get_number_of_vertices() to Graph (and this should be
        # used instead of g.adjList.offsets.size - 1)
        num_verts = g.adjList.offsets.size - 1
        df = cudf.DataFrame()
        df['vertex'] = cudf.Series(np.zeros(num_verts, dtype=np.int32))
        cdef gdf_column c_index_col = get_gdf_column_view(df['vertex'])
        g.adjList.get_vertex_identifiers(&c_index_col)
        df['x'] = cudf.Series(np.zeros(num_verts, dtype=np.float32))
        df['y'] = cudf.Series(np.zeros(num_verts, dtype=np.float32))
        cdef uintptr_t c_louvain_x_ptr = df['x'].__cuda_array_interface__['data'][0]
        cdef uintptr_t c_louvain_y_ptr = df['y'].__cuda_array_interface__['data'][1]


        force_atlas.force_atlas(<Graph*>g,
                        <void*>c_fa_x_ptr,
                        <void*>c_fa_y_ptr,
                        <int>max_iter,
                        <float>gravity,
                        <float>scaling_ratio,
                        <float>edge_weight_influence,
                        <int>lin_log_mode,
                        <int>prevent_overlapping)


        return df
