module plane_scheduler(
  input  clk,
  input  rst_n, // async active-low reset
  input  start, // pulse high to start computation
  input  [15:0] inspect_time [0:3], // inspection times for 4 airports
  input  [15:0] flight_times [0:3][0:3], // 4x4 flight time matrix (not directly indexed by flights here)
  input  [1:0]  flight_s [0:3], // source airports for 4 flights
  input  [1:0]  flight_f [0:3], // destination airports for 4 flights
  input  [15:0] flight_t [0:3], // departure times for 4 flights
  output reg [2:0] plane_count, // min planes needed (0-4)
  output reg       done
);

  // FSM states
  typedef enum logic [1:0] {
    IDLE  = 2'b00,
    CALC  = 2'b01,
    DONE  = 2'b10
  } state_t;

  state_t state, next_state;

  // 100-cycle latency counter
  reg [6:0] cycle_cnt; // enough for counting to 100

  // Adjacency matrix: can_use[i][j] = 1 if flight i can be immediately followed by flight j
  reg can_use [0:3][0:3];

  // Internal wires for connectivity computation
  integer i, j;

  // Precompute connectivity in parallel (combinational)
  // Condition:
  // flight j can reuse plane from flight i if:
  //   flight_t[j] >= flight_t[i] + flight_times[src_i][dst_i] + inspect_time[dst_i]
  // Note: Using flight_s[i] and flight_f[i] for travel time indexing.
  always @* begin
    for (i = 0; i < 4; i = i + 1) begin
      for (j = 0; j < 4; j = j + 1) begin
        if (i == j) begin
          can_use[i][j] = 1'b0;
        end else begin
          // travel time from src_i to dst_i
          // Index flight_times by airports of flight i;
          // assumes flight_times[a][b] is time from airport a to b
          if (flight_t[j] >= (flight_t[i]
                               + flight_times[flight_s[i]][flight_f[i]]
                               + inspect_time[flight_f[i]])) begin
            can_use[i][j] = 1'b1;
          end else begin
            can_use[i][j] = 1'b0;
          end
        end
      end
    end
  end

  // Maximum bipartite matching on 4x4 using brute-force enumeration.
  // Left side: flights (as predecessors), Right side: flights (as successors).
  // We only allow edges where can_use[i][j] == 1 and i != j.
  // Find maximum cardinality matching size in [0..4].

  function automatic [2:0] max_matching_4x4(input reg m[0:3][0:3]);
    integer a0,a1,a2,a3; // matches right nodes for left nodes 0..3; -1 if none
    integer used0,used1,used2,used3;
    integer i_choice0, i_choice1, i_choice2, i_choice3;
    integer best, cur;

    // We'll iterate over all possibilities for each left node:
    // For each left i, choose any right j where m[i][j]==1 or choose no match.
    // Encode "no match" as 4.

    best = 0;

    for (i_choice0 = 0; i_choice0 < 5; i_choice0 = i_choice0 + 1) begin
      if (i_choice0 == 4 || m[0][i_choice0]) begin
        for (i_choice1 = 0; i_choice1 < 5; i_choice1 = i_choice1 + 1) begin
          if (i_choice1 == 4 || m[1][i_choice1]) begin
            for (i_choice2 = 0; i_choice2 < 5; i_choice2 = i_choice2 + 1) begin
              if (i_choice2 == 4 || m[2][i_choice2]) begin
                for (i_choice3 = 0; i_choice3 < 5; i_choice3 = i_choice3 + 1) begin
                  if (i_choice3 == 4 || m[3][i_choice3]) begin
                    // Check uniqueness of chosen right nodes (except 4 which is no match)
                    used0 = 0; used1 = 0; used2 = 0; used3 = 0;

                    // Mark used rights
                    if (i_choice0 < 4) begin
                      case (i_choice0)
                        0: used0 = used0 + 1;
                        1: used1 = used1 + 1;
                        2: used2 = used2 + 1;
                        3: used3 = used3 + 1;
                      endcase
                    end
                    if (i_choice1 < 4) begin
                      case (i_choice1)
                        0: used0 = used0 + 1;
                        1: used1 = used1 + 1;
                        2: used2 = used2 + 1;
                        3: used3 = used3 + 1;
                      endcase
                    end
                    if (i_choice2 < 4) begin
                      case (i_choice2)
                        0: used0 = used0 + 1;
                        1: used1 = used1 + 1;
                        2: used2 = used2 + 1;
                        3: used3 = used3 + 1;
                      endcase
                    end
                    if (i_choice3 < 4) begin
                      case (i_choice3)
                        0: used0 = used0 + 1;
                        1: used1 = used1 + 1;
                        2: used2 = used2 + 1;
                        3: used3 = used3 + 1;
                      endcase
                    end

                    // Validate that no right node is used more than once
                    if ((used0 <= 1) && (used1 <= 1) && (used2 <= 1) && (used3 <= 1)) begin
                      cur = 0;
                      if (i_choice0 < 4) cur = cur + 1;
                      if (i_choice1 < 4) cur = cur + 1;
                      if (i_choice2 < 4) cur = cur + 1;
                      if (i_choice3 < 4) cur = cur + 1;
                      if (cur > best)
                        best = cur;
                    end

                  end
                end
              end
            end
          end
        end
      end
    end

    max_matching_4x4 = best[2:0];
  endfunction

  // Registered max matching result
  reg [2:0] max_match;

  // FSM sequential
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state       <= IDLE;
      cycle_cnt   <= 7'd0;
      plane_count <= 3'd0;
      max_match   <= 3'd0;
      done        <= 1'b0;
    end else begin
      state <= next_state;

      case (state)
        IDLE: begin
          done      <= 1'b0;
          cycle_cnt <= 7'd0;
          if (start) begin
            // Latch matching result at start (connectivity precomputed combinationally)
            max_match <= max_matching_4x4(can_use);
          end
        end

        CALC: begin
          done <= 1'b0;
          if (cycle_cnt < 7'd100)
            cycle_cnt <= cycle_cnt + 7'd1;

          if (cycle_cnt == 7'd99) begin
            // After 100 cycles from enter CALC (0..99), finalize result
            // Minimum planes = total flights (4) - max_match
            plane_count <= 3'd4 - max_match;
          end
        end

        DONE: begin
          done <= 1'b1;
        end

        default: begin
          done <= 1'b0;
        end
      endcase
    end
  end

  // FSM next state logic
  always @* begin
    next_state = state;
    case (state)
      IDLE: begin
        if (start)
          next_state = CALC;
      end

      CALC: begin
        if (cycle_cnt == 7'd100)
          next_state = DONE;
      end

      DONE: begin
        if (!start)
          next_state = IDLE;
      end

      default: next_state = IDLE;
    endcase
  end

endmodule