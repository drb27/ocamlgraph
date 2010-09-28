(**************************************************************************)
(*                                                                        *)
(*  This file is part of OcamlGraph.                                      *)
(*                                                                        *)
(*  Copyright (C) 2009                                                    *)
(*    CEA (Commissariat à l'Énergie Atomique)                             *)
(*                                                                        *)
(*  you can redistribute it and/or modify it under the terms of the GNU   *)
(*  Lesser General Public License as published by the Free Software       *)
(*  Foundation, version 2.1, with a linking exception.                    *)
(*                                                                        *)
(*  It is distributed in the hope that it will be useful,                 *)
(*  but WITHOUT ANY WARRANTY; without even the implied warranty of        *)
(*  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the         *)
(*  GNU Lesser General Public License for more details.                   *)
(*                                                                        *)
(*  See the file ../LICENSE for more details.                             *)
(*                                                                        *)
(*  Author:                                                               *)
(*    - Benoit Bataille  (benoit.bataille@gmail.com)                      *)
(*                                                                        *)
(**************************************************************************)

(** This functor creates a model centered on a vertex from a graph *)
module SubTreeMake (G : Graph.Graphviz.GraphWithDotAttrs) : sig

  type cluster = string

  module Tree : Sig.G
    with type t = Graph.Imperative.Digraph.Abstract(G.V).t
    and type V.label = G.V.t
  module TreeManipulation : sig
    type tree
    val make : G.t -> G.V.t -> int -> int -> tree
    val get_structure : tree -> Tree.t
    val get_tree_vertices : G.V.t -> tree -> Tree.V.t list
    val get_graph_vertex : Tree.V.t -> tree -> G.V.t
    val is_ghost_node : Tree.V.t -> tree -> bool
    val is_ghost_edge : Tree.E.t -> tree -> bool
  end

  class tree_model :
    (Tree.V.t, Tree.E.t, cluster) XDot.graph_layout ->
    TreeManipulation.tree -> [Tree.V.t, Tree.E.t, cluster]
    DGraphModel.abstract_model

  val get_tree : unit -> TreeManipulation.tree option

  val from_graph :
    ?cmd:string ->
    ?tmp_name:string ->
    ?depth_forward:int ->
    ?depth_backward:int ->
    [> `widget] Gtk.obj -> G.t -> G.V.t -> tree_model

end

(** Creates a model centered on a vertex from a dot model *)
module SubTreeDotModelMake : sig

  type cluster = string

  module Tree : Sig.G
    with type t = Graph.Imperative.Digraph.Abstract(DGraphModel.DotG.V).t
    and type V.label = DGraphModel.DotG.V.t
  module TreeManipulation : sig
    type tree
    val make : (DGraphModel.DotG.V.t, DGraphModel.DotG.E.t, string)
      DGraphModel.abstract_model -> DGraphModel.DotG.V.t ->
      int -> int -> tree
    val get_structure : tree -> Tree.t
    val get_tree_vertices : DGraphModel.DotG.V.t -> tree -> Tree.V.t list
    val get_graph_vertex : Tree.V.t -> tree -> DGraphModel.DotG.V.t
    val is_ghost_node : Tree.V.t -> tree -> bool
    val is_ghost_edge : Tree.E.t -> tree -> bool
  end

  class tree_model :
    (Tree.V.t, Tree.E.t, cluster) XDot.graph_layout ->
    TreeManipulation.tree -> [Tree.V.t, Tree.E.t, cluster]
    DGraphModel.abstract_model

  val get_tree : unit -> TreeManipulation.tree option

  val from_model :
    ?depth_forward:int ->
    ?depth_backward:int ->
    (DGraphModel.DotG.V.t, DGraphModel.DotG.E.t, string)
    DGraphModel.abstract_model -> DGraphModel.DotG.V.t -> tree_model

end