// Generated by pmgen.py from techlibs/quicklogic/ql_dsp_macc.pmg

struct ql_dsp_macc_pm {
  Module *module;
  SigMap sigmap;
  std::function<void()> on_accept;
  bool setup_done;
  bool generate_mode;
  int accept_cnt;

  uint32_t rngseed;
  int rng(unsigned int n) {
    rngseed ^= rngseed << 13;
    rngseed ^= rngseed >> 17;
    rngseed ^= rngseed << 5;
    return rngseed % n;
  }

  typedef std::tuple<> index_1_key_type;
  typedef std::tuple<Cell*> index_1_value_type;
  dict<index_1_key_type, vector<index_1_value_type>> index_1;
  typedef std::tuple<SigSpec> index_3_key_type;
  typedef std::tuple<Cell*, IdString, IdString> index_3_value_type;
  dict<index_3_key_type, vector<index_3_value_type>> index_3;
  typedef std::tuple<SigSpec, SigSpec> index_4_key_type;
  typedef std::tuple<Cell*, IdString, IdString> index_4_value_type;
  dict<index_4_key_type, vector<index_4_value_type>> index_4;
  typedef std::tuple<SigSpec, SigSpec> index_5_key_type;
  typedef std::tuple<Cell*> index_5_value_type;
  dict<index_5_key_type, vector<index_5_value_type>> index_5;
  dict<SigBit, pool<Cell*>> sigusers;
  pool<Cell*> blacklist_cells;
  pool<Cell*> autoremove_cells;
  dict<Cell*,int> rollback_cache;
  int rollback;

  struct state_ql_dsp_macc_t {
    Cell* add;
    IdString add_ba;
    Cell* ff;
    Cell* mul;
    Cell* mux;
    IdString mux_ab;
    bool mux_in_pattern;
    bool output_registered;
  } st_ql_dsp_macc;

  struct udata_ql_dsp_macc_t {
  } ud_ql_dsp_macc;

  IdString id_b_A{"\\A"};
  IdString id_b_B{"\\B"};
  IdString id_b_CLK_POLARITY{"\\CLK_POLARITY"};
  IdString id_b_D{"\\D"};
  IdString id_b_Q{"\\Q"};
  IdString id_b_Y{"\\Y"};
  IdString id_d_add{"$add"};
  IdString id_d_adff{"$adff"};
  IdString id_d_adffe{"$adffe"};
  IdString id_d_dff{"$dff"};
  IdString id_d_dffe{"$dffe"};
  IdString id_d_mul{"$mul"};
  IdString id_d_mux{"$mux"};
  IdString id_d_sub{"$sub"};

  void add_siguser(const SigSpec &sig, Cell *cell) {
    for (auto bit : sigmap(sig)) {
      if (bit.wire == nullptr) continue;
      sigusers[bit].insert(cell);
    }
  }

  void blacklist(Cell *cell) {
    if (cell != nullptr && blacklist_cells.insert(cell).second) {
      auto ptr = rollback_cache.find(cell);
      if (ptr == rollback_cache.end()) return;
      int rb = ptr->second;
      if (rollback == 0 || rollback > rb)
        rollback = rb;
    }
  }

  void autoremove(Cell *cell) {
    if (cell != nullptr) {
      autoremove_cells.insert(cell);
      blacklist(cell);
    }
  }

  SigSpec port(Cell *cell, IdString portname) {
    try {
      return sigmap(cell->getPort(portname));
    } catch(std::out_of_range&) { log_error("Accessing non existing port %s\n",portname.c_str()); }
  }

  SigSpec port(Cell *cell, IdString portname, const SigSpec& defval) {
    return sigmap(cell->connections_.at(portname, defval));
  }

  Const param(Cell *cell, IdString paramname) {
    try {
      return cell->getParam(paramname);
    } catch(std::out_of_range&) { log_error("Accessing non existing parameter %s\n",paramname.c_str()); }
  }

  Const param(Cell *cell, IdString paramname, const Const& defval) {
    return cell->parameters.at(paramname, defval);
  }

  int nusers(const SigSpec &sig) {
    pool<Cell*> users;
    for (auto bit : sigmap(sig))
      for (auto user : sigusers[bit])
        users.insert(user);
    return GetSize(users);
  }

  ql_dsp_macc_pm(Module *module, const vector<Cell*> &cells) :
      module(module), sigmap(module), setup_done(false), generate_mode(false), rngseed(12345678) {
    setup(cells);
  }

  ql_dsp_macc_pm(Module *module) :
      module(module), sigmap(module), setup_done(false), generate_mode(false), rngseed(12345678) {
  }

  void setup(const vector<Cell*> &cells) {
    log_assert(!setup_done);
    setup_done = true;
    for (auto port : module->ports)
      add_siguser(module->wire(port), nullptr);
    for (auto cell : module->cells())
      for (auto &conn : cell->connections())
        add_siguser(conn.second, cell);
    for (auto cell : cells) {
      do {
        Cell *mul = cell;
        index_1_value_type value;
        std::get<0>(value) = cell;
        if (!(mul->type.in(id_d_mul))) continue;
        if (!(nusers(port(mul, id_b_Y)) <= 3)) continue;
        index_1_key_type key;
        index_1[key].push_back(value);
      } while (0);
      do {
        Cell *add = cell;
        index_3_value_type value;
        std::get<0>(value) = cell;
        if (!(add->type.in(id_d_add, id_d_sub))) continue;
        vector<IdString> _pmg_choices_AB = {id_b_A, id_b_B};
        for (const IdString &AB : _pmg_choices_AB) {
        std::get<1>(value) = AB;
        IdString &BA = std::get<2>(value);
        BA = (AB == id_b_A ? id_b_B : id_b_A);
        index_3_key_type key;
        std::get<0>(key) = port(add, AB);
        index_3[key].push_back(value);
        }
      } while (0);
      do {
        Cell *mux = cell;
        index_4_value_type value;
        std::get<0>(value) = cell;
        if (!(mux->type.in(id_d_mux))) continue;
        vector<IdString> _pmg_choices_AB = {id_b_A, id_b_B};
        for (const IdString &AB : _pmg_choices_AB) {
        std::get<1>(value) = AB;
        IdString &BA = std::get<2>(value);
        BA = (AB == id_b_A ? id_b_B : id_b_A);
        index_4_key_type key;
        std::get<0>(key) = port(mux, AB);
        std::get<1>(key) = port(mux, BA);
        index_4[key].push_back(value);
        }
      } while (0);
      do {
        Cell *ff = cell;
        index_5_value_type value;
        std::get<0>(value) = cell;
        if (!(ff->type.in(id_d_dff, id_d_adff, id_d_dffe, id_d_adffe))) continue;
        if (!(param(ff, id_b_CLK_POLARITY).as_bool())) continue;
        index_5_key_type key;
        std::get<0>(key) = port(ff, id_b_D);
        std::get<1>(key) = port(ff, id_b_Q);
        index_5[key].push_back(value);
      } while (0);
    }
  }

  ~ql_dsp_macc_pm() {
    for (auto cell : autoremove_cells)
      module->remove(cell);
  }

  int run_ql_dsp_macc(std::function<void()> on_accept_f) {
    log_assert(setup_done);
    accept_cnt = 0;
    on_accept = on_accept_f;
    rollback = 0;
    st_ql_dsp_macc.add = nullptr;
    st_ql_dsp_macc.add_ba = IdString();
    st_ql_dsp_macc.ff = nullptr;
    st_ql_dsp_macc.mul = nullptr;
    st_ql_dsp_macc.mux = nullptr;
    st_ql_dsp_macc.mux_ab = IdString();
    st_ql_dsp_macc.mux_in_pattern = bool();
    st_ql_dsp_macc.output_registered = bool();
    block_0(1);
    log_assert(rollback_cache.empty());
    return accept_cnt;
  }

  int run_ql_dsp_macc(std::function<void(ql_dsp_macc_pm&)> on_accept_f) {
    return run_ql_dsp_macc([&](){on_accept_f(*this);});
  }

  int run_ql_dsp_macc() {
    return run_ql_dsp_macc([](){});
  }

  void block_subpattern_ql_dsp_macc_(int recursion) { block_0(recursion); }

  // techlibs/quicklogic/ql_dsp_macc.pmg:21
  void block_0(int recursion YS_MAYBE_UNUSED) {
    bool &mux_in_pattern YS_MAYBE_UNUSED = st_ql_dsp_macc.mux_in_pattern;

#define reject do { goto rollback_label; } while(0)
#define accept do { accept_cnt++; on_accept(); if (rollback) goto rollback_label; } while(0)
#define finish do { rollback = -1; goto rollback_label; } while(0)
#define branch do { block_1(recursion+1); if (rollback) goto rollback_label; } while(0)
#define subpattern(pattern_name) do { block_subpattern_ql_dsp_macc_ ## pattern_name (recursion+1); if (rollback) goto rollback_label; } while(0)
      mux_in_pattern = false;
      branch;
      mux_in_pattern = true;

    block_1(recursion+1);
#undef reject
#undef accept
#undef finish
#undef branch
#undef subpattern

rollback_label:
    YS_MAYBE_UNUSED;

    mux_in_pattern = bool();
  }

  // techlibs/quicklogic/ql_dsp_macc.pmg:28
  void block_1(int recursion YS_MAYBE_UNUSED) {
    const bool &mux_in_pattern YS_MAYBE_UNUSED = st_ql_dsp_macc.mux_in_pattern;
    Cell* &mul YS_MAYBE_UNUSED = st_ql_dsp_macc.mul;
    Cell* _pmg_backup_mul = mul;

    index_1_key_type key;
    auto cells_ptr = index_1.find(key);

    if (cells_ptr != index_1.end()) {
      const vector<index_1_value_type> &cells = cells_ptr->second;
      for (int _pmg_idx = 0; _pmg_idx < GetSize(cells); _pmg_idx++) {
        mul = std::get<0>(cells[_pmg_idx]);
        if (blacklist_cells.count(mul)) continue;
        if (!(nusers(port(mul, id_b_Y)) == (mux_in_pattern ? 3 : 2))) continue;
        auto rollback_ptr = rollback_cache.insert(make_pair(std::get<0>(cells[_pmg_idx]), recursion));
        block_2(recursion+1);
        if (rollback_ptr.second)
          rollback_cache.erase(rollback_ptr.first);
        if (rollback) {
          if (rollback != recursion) {
            mul = _pmg_backup_mul;
            return;
          }
          rollback = 0;
        }
      }
    }

    mul = nullptr;
    mul = _pmg_backup_mul;
  }

  // techlibs/quicklogic/ql_dsp_macc.pmg:36
  void block_2(int recursion YS_MAYBE_UNUSED) {
    Cell* const &mul YS_MAYBE_UNUSED = st_ql_dsp_macc.mul;
    const bool &mux_in_pattern YS_MAYBE_UNUSED = st_ql_dsp_macc.mux_in_pattern;
    bool &output_registered YS_MAYBE_UNUSED = st_ql_dsp_macc.output_registered;

#define reject do { goto rollback_label; } while(0)
#define accept do { accept_cnt++; on_accept(); if (rollback) goto rollback_label; } while(0)
#define finish do { rollback = -1; goto rollback_label; } while(0)
#define branch do { block_3(recursion+1); if (rollback) goto rollback_label; } while(0)
#define subpattern(pattern_name) do { block_subpattern_ql_dsp_macc_ ## pattern_name (recursion+1); if (rollback) goto rollback_label; } while(0)
      output_registered = false;
      branch;
      output_registered = true;

    block_3(recursion+1);
#undef reject
#undef accept
#undef finish
#undef branch
#undef subpattern

rollback_label:
    YS_MAYBE_UNUSED;

    output_registered = bool();
  }

  // techlibs/quicklogic/ql_dsp_macc.pmg:42
  void block_3(int recursion YS_MAYBE_UNUSED) {
    Cell* const &mul YS_MAYBE_UNUSED = st_ql_dsp_macc.mul;
    const bool &mux_in_pattern YS_MAYBE_UNUSED = st_ql_dsp_macc.mux_in_pattern;
    const bool &output_registered YS_MAYBE_UNUSED = st_ql_dsp_macc.output_registered;
    Cell* &add YS_MAYBE_UNUSED = st_ql_dsp_macc.add;
    IdString &add_ba YS_MAYBE_UNUSED = st_ql_dsp_macc.add_ba;
    Cell* _pmg_backup_add = add;

    index_3_key_type key;
    std::get<0>(key) = port(mul, id_b_Y);
    auto cells_ptr = index_3.find(key);

    if (cells_ptr != index_3.end()) {
      const vector<index_3_value_type> &cells = cells_ptr->second;
      for (int _pmg_idx = 0; _pmg_idx < GetSize(cells); _pmg_idx++) {
        add = std::get<0>(cells[_pmg_idx]);
        const IdString &AB YS_MAYBE_UNUSED = std::get<1>(cells[_pmg_idx]);
        const IdString &BA YS_MAYBE_UNUSED = std::get<2>(cells[_pmg_idx]);
        if (blacklist_cells.count(add)) continue;
        if (!(nusers(port(add, id_b_Y)) == (!mux_in_pattern && !output_registered ? 3 : 2))) continue;
        auto _pmg_backup_add_ba = add_ba;
        add_ba = BA;
        auto rollback_ptr = rollback_cache.insert(make_pair(std::get<0>(cells[_pmg_idx]), recursion));
        block_4(recursion+1);
        add_ba = _pmg_backup_add_ba;
        if (rollback_ptr.second)
          rollback_cache.erase(rollback_ptr.first);
        if (rollback) {
          if (rollback != recursion) {
            add = _pmg_backup_add;
            return;
          }
          rollback = 0;
        }
      }
    }

    add = nullptr;
    add = _pmg_backup_add;
  }

  // techlibs/quicklogic/ql_dsp_macc.pmg:56
  void block_4(int recursion YS_MAYBE_UNUSED) {
    Cell* const &add YS_MAYBE_UNUSED = st_ql_dsp_macc.add;
    const IdString &add_ba YS_MAYBE_UNUSED = st_ql_dsp_macc.add_ba;
    Cell* const &mul YS_MAYBE_UNUSED = st_ql_dsp_macc.mul;
    const bool &mux_in_pattern YS_MAYBE_UNUSED = st_ql_dsp_macc.mux_in_pattern;
    const bool &output_registered YS_MAYBE_UNUSED = st_ql_dsp_macc.output_registered;
    Cell* &mux YS_MAYBE_UNUSED = st_ql_dsp_macc.mux;
    IdString &mux_ab YS_MAYBE_UNUSED = st_ql_dsp_macc.mux_ab;
    Cell* _pmg_backup_mux = mux;

    if (!(mux_in_pattern)) {
      mux = nullptr;
      block_5(recursion+1);
      mux = _pmg_backup_mux;
      return;
    }

    index_4_key_type key;
    std::get<0>(key) = port(mul, id_b_Y);
    std::get<1>(key) = port(add, id_b_Y);
    auto cells_ptr = index_4.find(key);

    if (cells_ptr != index_4.end()) {
      const vector<index_4_value_type> &cells = cells_ptr->second;
      for (int _pmg_idx = 0; _pmg_idx < GetSize(cells); _pmg_idx++) {
        mux = std::get<0>(cells[_pmg_idx]);
        const IdString &AB YS_MAYBE_UNUSED = std::get<1>(cells[_pmg_idx]);
        const IdString &BA YS_MAYBE_UNUSED = std::get<2>(cells[_pmg_idx]);
        if (blacklist_cells.count(mux)) continue;
        if (!(nusers(port(mux, id_b_Y)) == (output_registered ? 2 : 3))) continue;
        auto _pmg_backup_mux_ab = mux_ab;
        mux_ab = AB;
        auto rollback_ptr = rollback_cache.insert(make_pair(std::get<0>(cells[_pmg_idx]), recursion));
        block_5(recursion+1);
        mux_ab = _pmg_backup_mux_ab;
        if (rollback_ptr.second)
          rollback_cache.erase(rollback_ptr.first);
        if (rollback) {
          if (rollback != recursion) {
            mux = _pmg_backup_mux;
            return;
          }
          rollback = 0;
        }
      }
    }

    mux = nullptr;
    mux = _pmg_backup_mux;
  }

  // techlibs/quicklogic/ql_dsp_macc.pmg:67
  void block_5(int recursion YS_MAYBE_UNUSED) {
    Cell* const &add YS_MAYBE_UNUSED = st_ql_dsp_macc.add;
    const IdString &add_ba YS_MAYBE_UNUSED = st_ql_dsp_macc.add_ba;
    Cell* const &mul YS_MAYBE_UNUSED = st_ql_dsp_macc.mul;
    Cell* const &mux YS_MAYBE_UNUSED = st_ql_dsp_macc.mux;
    const IdString &mux_ab YS_MAYBE_UNUSED = st_ql_dsp_macc.mux_ab;
    const bool &mux_in_pattern YS_MAYBE_UNUSED = st_ql_dsp_macc.mux_in_pattern;
    const bool &output_registered YS_MAYBE_UNUSED = st_ql_dsp_macc.output_registered;
    Cell* &ff YS_MAYBE_UNUSED = st_ql_dsp_macc.ff;
    Cell* _pmg_backup_ff = ff;

    index_5_key_type key;
    std::get<0>(key) = mux_in_pattern ? port(mux, id_b_Y) : port(add, id_b_Y);;
    std::get<1>(key) = port(add, add_ba);
    auto cells_ptr = index_5.find(key);

    if (cells_ptr != index_5.end()) {
      const vector<index_5_value_type> &cells = cells_ptr->second;
      for (int _pmg_idx = 0; _pmg_idx < GetSize(cells); _pmg_idx++) {
        ff = std::get<0>(cells[_pmg_idx]);
        if (blacklist_cells.count(ff)) continue;
        if (!(nusers(port(ff, id_b_Q)) == (output_registered ? 3 : 2))) continue;
        auto rollback_ptr = rollback_cache.insert(make_pair(std::get<0>(cells[_pmg_idx]), recursion));
        block_6(recursion+1);
        if (rollback_ptr.second)
          rollback_cache.erase(rollback_ptr.first);
        if (rollback) {
          if (rollback != recursion) {
            ff = _pmg_backup_ff;
            return;
          }
          rollback = 0;
        }
      }
    }

    ff = nullptr;
    ff = _pmg_backup_ff;
  }

  // techlibs/quicklogic/ql_dsp_macc.pmg:75
  void block_6(int recursion YS_MAYBE_UNUSED) {
    Cell* const &add YS_MAYBE_UNUSED = st_ql_dsp_macc.add;
    const IdString &add_ba YS_MAYBE_UNUSED = st_ql_dsp_macc.add_ba;
    Cell* const &ff YS_MAYBE_UNUSED = st_ql_dsp_macc.ff;
    Cell* const &mul YS_MAYBE_UNUSED = st_ql_dsp_macc.mul;
    Cell* const &mux YS_MAYBE_UNUSED = st_ql_dsp_macc.mux;
    const IdString &mux_ab YS_MAYBE_UNUSED = st_ql_dsp_macc.mux_ab;
    const bool &mux_in_pattern YS_MAYBE_UNUSED = st_ql_dsp_macc.mux_in_pattern;
    const bool &output_registered YS_MAYBE_UNUSED = st_ql_dsp_macc.output_registered;

#define reject do { goto rollback_label; } while(0)
#define accept do { accept_cnt++; on_accept(); if (rollback) goto rollback_label; } while(0)
#define finish do { rollback = -1; goto rollback_label; } while(0)
#define branch do { block_7(recursion+1); if (rollback) goto rollback_label; } while(0)
#define subpattern(pattern_name) do { block_subpattern_ql_dsp_macc_ ## pattern_name (recursion+1); if (rollback) goto rollback_label; } while(0)
      accept;

    block_7(recursion+1);
#undef reject
#undef accept
#undef finish
#undef branch
#undef subpattern

rollback_label:
    YS_MAYBE_UNUSED;
  }

  void block_7(int recursion YS_MAYBE_UNUSED) {
  }
};
