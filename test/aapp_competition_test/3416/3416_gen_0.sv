module train_route_optimizer(
  input        clk,
  input        rst_n,
  input        start,
  input  [3:0] num_cities,
  input  [15:0] adj_matrix,
  output reg [1:0] min_flights,
  output reg [3:0] airports,
  output reg       done
);

  // State encoding
  localparam IDLE       = 2'b00;
  localparam PROCESSING = 2'b01;
  localparam DONE       = 2'b10;

  reg [1:0] state, next_state;

  // Latched inputs
  reg [3:0]  num_cities_r;
  reg [15:0] adj_matrix_r;

  // DAG validation (no self-loops, no cycles)
  reg dag_valid;

  // Longest path DP arrays
  // dist[i]: longest path length (in edges) ending at node i
  // mask[i]: bitmask of nodes participating in any longest path ending at i
  reg [1:0] dist [0:3];
  reg [3:0] mask [0:3];

  reg [1:0] max_dist;
  reg [3:0] best_mask;

  // Helpers for cycle detection and longest path computation
  function automatic [0:0] has_cycle;
    input [15:0] m;
    reg e00,e01,e02,e03;
    reg e10,e11,e12,e13;
    reg e20,e21,e22,e23;
    reg e30,e31,e32,e33;
  begin
    e00 = m[0];  e01 = m[1];  e02 = m[2];  e03 = m[3];
    e10 = m[4];  e11 = m[5];  e12 = m[6];  e13 = m[7];
    e20 = m[8];  e21 = m[9];  e22 = m[10]; e23 = m[11];
    e30 = m[12]; e31 = m[13]; e32 = m[14]; e33 = m[15];

    // Self loops
    if (e00 || e11 || e22 || e33) begin
      has_cycle = 1'b1;
    end else if ((e01 && e10) || (e02 && e20) || (e03 && e30) ||
                 (e12 && e21) || (e13 && e31) || (e23 && e32)) begin
      // 2-cycles
      has_cycle = 1'b1;
    end else if ((e01 && e12 && e20) || (e01 && e13 && e30) || (e02 && e21 && e10) ||
                 (e02 && e23 && e30) || (e03 && e31 && e10) || (e03 && e32 && e20) ||
                 (e10 && e02 && e21) || (e10 && e03 && e31) || (e12 && e23 && e31) ||
                 (e13 && e32 && e21) || (e20 && e01 && e12) || (e20 && e03 && e32) ||
                 (e21 && e13 && e30) || (e23 && e31 && e10) || (e30 && e01 && e13) ||
                 (e30 && e02 && e23) || (e31 && e12 && e20) || (e32 && e21 && e10)) begin
      // Simple 3-cycles (over-approximated set to remain combinational and small)
      has_cycle = 1'b1;
    end else begin
      // Over-approximate 4-cycles (any directed ring of length 4 along 0-1-2-3)
      if ((e01 && e12 && e23 && e30) || (e02 && e23 && e31 && e10) ||
          (e03 && e31 && e12 && e20) || (e03 && e32 && e21 && e10) ||
          (e02 && e21 && e13 && e30) || (e01 && e13 && e32 && e20)) begin
        has_cycle = 1'b1;
      end else begin
        has_cycle = 1'b0;
      end
    end
  end
  endfunction

  // Compute longest path (in edges) and mask for nodes within [0..num_cities_r-1].
  // For nodes >= num_cities_r, they are ignored.
  task automatic compute_longest_paths;
    input  [3:0]  n_cities;
    input  [15:0] m;
    output [1:0]  o_max_dist;
    output [3:0]  o_best_mask;

    reg [1:0] tdist [0:3];
    reg [3:0] tmask [0:3];

    integer i,j;
    reg [1:0] bestd;
    reg [3:0] bestm;

    reg [3:0] node_en;
    reg [3:0] reachable_src;

    begin
      // Enable mask for active cities (0..n_cities-1)
      node_en = 4'b0000;
      case (n_cities)
        4'd0: node_en = 4'b0000;
        4'd1: node_en = 4'b0001;
        4'd2: node_en = 4'b0011;
        4'd3: node_en = 4'b0111;
        default: node_en = 4'b1111;
      endcase

      // Initialize
      for (i = 0; i < 4; i = i + 1) begin
        if (node_en[i]) begin
          tdist[i] = 2'd0;
          tmask[i] = (4'b0001 << i);
        end else begin
          tdist[i] = 2'd0;
          tmask[i] = 4'b0000;
        end
      end

      // Paths relaxation with up to 3 iterations (max edges in 4-node DAG)
      // Each relaxation considers all edges i->j.
      for (integer iter = 0; iter < 3; iter = iter + 1) begin
        for (i = 0; i < 4; i = i + 1) begin
          if (node_en[i]) begin
            for (j = 0; j < 4; j = j + 1) begin
              if (node_en[j]) begin
                if (m[4*i + j]) begin
                  if (tdist[i] + 2'd1 > tdist[j]) begin
                    tdist[j] = tdist[i] + 2'd1;
                    tmask[j] = tmask[i] | (4'b0001 << j);
                  end else if (tdist[i] + 2'd1 == tdist[j]) begin
                    tmask[j] = tmask[j] | tmask[i] | (4'b0001 << j);
                  end
                end
              end
            end
          end
        end
      end

      // Aggregate overall best
      bestd = 2'd0;
      bestm = 4'b0000;
      for (i = 0; i < 4; i = i + 1) begin
        if (node_en[i]) begin
          if (tdist[i] > bestd) begin
            bestd = tdist[i];
            bestm = tmask[i];
          end else if (tdist[i] == bestd) begin
            bestm = bestm | tmask[i];
          end
        end
      end

      o_max_dist  = bestd;
      o_best_mask = bestm & node_en;
    end
  endtask

  // Sequential state register
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state        <= IDLE;
      num_cities_r <= 4'd0;
      adj_matrix_r <= 16'd0;
      min_flights  <= 2'd0;
      airports     <= 4'd0;
      done         <= 1'b0;
    end else begin
      state <= next_state;

      case (state)
        IDLE: begin
          done        <= 1'b0;
          min_flights <= 2'd0;
          airports    <= 4'd0;
          if (start) begin
            num_cities_r <= num_cities;
            adj_matrix_r <= adj_matrix;
          end
        end

        PROCESSING: begin
          // One-cycle processing: compute DAG validity and longest paths
          dag_valid = !has_cycle(adj_matrix_r);

          if (!dag_valid) begin
            // If not a DAG, per spec treat as no valid routes
            min_flights <= 2'd0;
            airports    <= 4'd0;
          end else begin
            compute_longest_paths(num_cities_r, adj_matrix_r, max_dist, best_mask);

            // min_flights = num_cities - k - 1; clamp to 0..3
            // Use 3-bit internal to avoid underflow, then saturate to 2 bits
            begin : compute_min
              reg [2:0] tmp;
              tmp = {1'b0, num_cities_r} - {1'b0, max_dist} - 3'd1;
              if (tmp[2]) begin
                min_flights <= 2'd0;
              end else if (tmp > 3'd3) begin
                min_flights <= 2'd3;
              end else begin
                min_flights <= tmp[1:0];
              end
            end

            airports <= best_mask;
          end
        end

        DONE: begin
          done <= 1'b1;
        end

        default: begin
          done        <= 1'b0;
          min_flights <= 2'd0;
          airports    <= 4'd0;
        end
      endcase
    end
  end

  // Next state logic
  always @(*) begin
    next_state = state;
    case (state)
      IDLE: begin
        if (start)
          next_state = PROCESSING;
        else
          next_state = IDLE;
      end

      PROCESSING: begin
        // All computations done within one cycle
        next_state = DONE;
      end

      DONE: begin
        // Wait for start to go low then high again to restart
        if (!start)
          next_state = IDLE;
        else
          next_state = DONE;
      end

      default: next_state = IDLE;
    endcase
  end

endmodule