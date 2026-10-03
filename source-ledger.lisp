;;;; Source ledger, written by scripts/gen-dist.lisp and
;;;; scripts/seed-ledger.lisp. See README.md, "Source ledger".
;;;;
;;;; One line per project: the repository a release is imported from,
;;;; the ids the host gave that repository and its owner, and the commit
;;;; imported last. Delete a line to have the next run record it afresh.

(:source-ledger
 :format-version 1
 :entries
 ((:lib "trivial-gray-streams" :host :github :source "trivial-gray-streams/trivial-gray-streams" :name "trivial-gray-streams/trivial-gray-streams" :repo-id 16681816 :owner-id 6634879 :commit "257d73ec36958beb7d49eba5567d5409827197b7")
  (:lib "flexi-streams" :host :github :source "dotcl/flexi-streams" :name "dotcl/flexi-streams" :repo-id 1376837657 :owner-id 270163380 :commit "561a40d360a17a6052a7781613684ceb86f797fc")
  (:lib "micros" :host :github :source "dotcl/micros" :name "dotcl/micros" :repo-id 1287522947 :owner-id 270163380 :commit "3f81d65bd407d4a2f3601fd8afc95988a9958fa9")
  (:lib "babel" :host :github :source "snmsts/babel" :name "snmsts/babel" :repo-id 49011449 :owner-id 71670 :commit "83e14536ef85cee621e5357de04f233afdd7a57a")
  (:lib "cffi" :host :github :source "dotcl/cffi" :name "dotcl/cffi" :repo-id 1309844323 :owner-id 270163380 :commit "a39090570def9104ae2a5918a30363aaf8519680")
  (:lib "trivial-cltl2" :host :github :source "dotcl/trivial-cltl2" :name "dotcl/trivial-cltl2" :repo-id 1370865754 :owner-id 270163380 :commit "cddd7f3ee03cdce60a40b2b87d3fa65725c62bdc")
  (:lib "trivial-features" :host :github :source "trivial-features/trivial-features" :name "trivial-features/trivial-features" :repo-id 1807356 :owner-id 804897 :commit "828246a1c1efdcad94c1ba2f2a210bb9cb4cde3e")
  (:lib "trivial-garbage" :host :github :source "trivial-garbage/trivial-garbage" :name "trivial-garbage/trivial-garbage" :repo-id 1807370 :owner-id 804899 :commit "f0663f7b0c900ed78ac19f6db306e7c6cac999fd")
  (:lib "bordeaux-threads" :host :github :source "dotcl/bordeaux-threads" :name "dotcl/bordeaux-threads" :repo-id 1316192667 :owner-id 270163380 :commit "968665ea147277d0e2fe089ae05c5d3e9375a1e3")
  (:lib "atomics" :host :codeberg :source "shinmera/atomics" :name "shinmera/atomics" :repo-id 691924 :owner-id 87977 :commit "1caed1aced6c552923e87e37e6e9cfdc185c06b0")
  (:lib "metatilities-base" :host :github :source "dotcl/metatilities-base" :name "dotcl/metatilities-base" :repo-id 1375374171 :owner-id 270163380 :commit "bb703f3bac80417eccbca4bc462c8f1314fb3ca0")
  (:lib "cl+ssl" :host :github :source "dotcl/cl-plus-ssl" :name "dotcl/cl-plus-ssl" :repo-id 1375374261 :owner-id 270163380 :commit "58f25cbdccf9e2e197269b4eed6787411f8030aa")
  (:lib "mmap" :host :codeberg :source "shinmera/mmap" :name "shinmera/mmap" :repo-id 692593 :owner-id 87977 :commit "d8d4fad5db120eb99559340a3a2cc74c53b9f09a")
  (:lib "dexador" :host :github :source "dotcl/dexador" :name "dotcl/dexador" :repo-id 1332831407 :owner-id 270163380 :commit "2428e1e2d009ca43dc9fc36f891cf8211a49a95d")
  (:lib "cl-fad" :host :github :source "edicl/cl-fad" :name "edicl/cl-fad" :repo-id 2293700 :owner-id 1013679 :commit "714257f064cbe326855701be1aa5ef1199f3c676")
  (:lib "float-features" :host :codeberg :source "shinmera/float-features" :name "shinmera/float-features" :repo-id 692260 :owner-id 87977 :commit "5f54e8734b2e959641633831571ece5501da8ded")
  (:lib "usocket" :host :github :source "dotcl/usocket" :name "dotcl/usocket" :repo-id 1330138516 :owner-id 270163380 :commit "a1c85732c1660d45bf82d94ea8394be609baedbb")
  (:lib "slime" :host :github :source "slime/slime" :name "slime/slime" :repo-id 15344025 :owner-id 6232135 :commit "82dfda1a83e22de6fad93f54f3201f5dec6754fb")
  (:lib "sly" :host :github :source "dotcl/sly" :name "dotcl/sly" :repo-id 1353143884 :owner-id 270163380 :commit "569456f0ab08e5491b64f6f994f8d1351769210c")
  (:lib "trivial-package-local-nicknames" :host :github :source "dotcl/trivial-package-local-nicknames" :name "dotcl/trivial-package-local-nicknames" :repo-id 1394446194 :owner-id 270163380 :commit "101a4ad8a391e6a67e12675a5e0e4341d6663753")
  (:lib "fset" :host :github :source "dotcl/fset" :name "dotcl/fset" :repo-id 1394446767 :owner-id 270163380 :commit "8ece8b8135f1c7cfa5b153b06a82cee92eca7917")
  (:lib "moptilities" :host :github :source "dotcl/moptilities" :name "dotcl/moptilities" :repo-id 1394447222 :owner-id 270163380 :commit "9f9a9a18c66a1cbb2078f02b090b462a352d9033")
  (:lib "series" :host :github :source "dotcl/series" :name "dotcl/series" :repo-id 1394448809 :owner-id 270163380 :commit "78111d52d560ca136c2c8a598739321dff5199c5")
  (:lib "cl-environments" :host :github :source "dotcl/cl-environments" :name "dotcl/cl-environments" :repo-id 1398950085 :owner-id 270163380 :commit "0a10e70e579fb16384bc408351003a7a3fd50bd4")))
