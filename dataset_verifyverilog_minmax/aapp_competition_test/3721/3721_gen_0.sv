module chemical_element_minimizer(
  input clk,
  input rst_n,
  input start,
  input [4:0] n,
  input [4:0] m,
  input [4:0] q,
  input [31:0] elements [31:0],  // 32 entries max, each [9:0] = {row[4:0], col[4:0]}
  output reg [5:0] minimal_purchases,
  output reg done
);

  // State machine states
  localparam IDLE     = 2'b00;
  localparam PROCESS  = 2'b01;
  localparam DONE     = 2'b10;

  // Union-Find storage (max 16+16=32 elements => 5-bit addressing)
  reg [4:0] parent [0:31];  // 5-bit parent pointers
  reg [3:0] rank   [0:31];  // 4-bit rank (max 16)

  reg [5:0] total_components;  // up to 32
  reg [5:0] cycle_counter;     // 0..34
  reg [1:0] ps, ns;

  // Union-Find with union-by-rank
  task union_find;
    input [4:0] a;
    input [4:0] b;
    // Non-blocking updates to avoid race conditions in simulation
    begin
      if (a != b) begin
        if (parent[a] == a && parent[b] == b) begin
          // Different roots: rank-based union, decrement if merged
          if (rank[a] < rank[b]) begin
            parent[a] <= b;
            if (total_components > 0) total_components <= total_components - 1;
          end else if (rank[a] > rank[b]) begin
            parent[b] <= a;
            if (total_components > 0) total_components <= total_components - 1;
          end else begin
            parent[b] <= a;
            rank[a] <= rank[a] + 1;
            if (total_components > 0) total_components <= total_components - 1;
          end
        end else begin
          // Path compression during find (non-blocking updates)
          if (parent[a] == a) begin
            // a is a root
            if (parent[b] == b) begin
              // both roots: decide by rank
              if (rank[a] < rank[b]) begin
                parent[a] <= b;
                if (total_components > 0) total_components <= total_components - 1;
              end else if (rank[a] > rank[b]) begin
                parent[b] <= a;
                if (total_components > 0) total_components <= total_components - 1;
              end else begin
                parent[b] <= a;
                rank[a] <= rank[a] + 1;
                if (total_components > 0) total_components <= total_components - 1;
              end
            end else begin
              // compress b root towards a root if beneficial
              if (rank[a] < rank[b]) begin
                parent[a] <= b;
                if (total_components > 0) total_components <= total_components - 1;
              end else if (rank[a] > rank[b]) begin
                parent[b] <= a;
                if (total_components > 0) total_components <= total_components - 1;
              end else begin
                parent[b] <= a;
                rank[a] <= rank[a] + 1;
                if (total_components > 0) total_components <= total_components - 1;
              end
            end
          end else begin
            // a not root: compress along the path (lightweight)
            if (parent[a] == a) begin
              // a root, b not root
              if (parent[b] == b) begin
                // shouldn't happen due to earlier branch, but keep for completeness
                if (rank[a] < rank[b]) begin
                  parent[a] <= b;
                  if (total_components > 0) total_components <= total_components - 1;
                end else if (rank[a] > rank[b]) begin
                  parent[b] <= a;
                  if (total_components > 0) total_components <= total_components - 1;
                end else begin
                  parent[b] <= a;
                  rank[a] <= rank[a] + 1;
                  if (total_components > 0) total_components <= total_components - 1;
                end
              end else begin
                // compress b
                if (rank[a] < rank[b]) begin
                  parent[a] <= b;
                  if (total_components > 0) total_components <= total_components - 1;
                end else if (rank[a] > rank[b]) begin
                  parent[b] <= a;
                  if (total_components > 0) total_components <= total_components - 1;
                end else begin
                  parent[b] <= a;
                  rank[a] <= rank[a] + 1;
                  if (total_components > 0) total_components <= total_components - 1;
                end
              end
            end else begin
              // Neither root: compress both in the style of earlier branch
              if (rank[a] < rank[b]) begin
                parent[a] <= b;
                if (total_components > 0) total_components <= total_components - 1;
              end else if (rank[a] > rank[b]) begin
                parent[b] <= a;
                if (total_components > 0) total_components <= total_components - 1;
              end else begin
                parent[b] <= a;
                rank[a] <= rank[a] + 1;
                if (total_components > 0) total_components <= total_components - 1;
              end
            end
          end
        end
      end
    end
  endtask

  // Synchronous state update
  always @(posedge clk) begin
    if (!rst_n) begin
      ps <= IDLE;
      done <= 1'b0;
      minimal_purchases <= 6'd0;
    end else begin
      ps <= ns;
    end
  end

  // State machine and processing
  always @(*) begin
    ns = ps;
    done = 1'b0;
    case (ps)
      IDLE: begin
        done = 1'b0;
        if (start) begin
          // Initialize union-find for n + m elements (max 32)
          total_components = {1'b0, n} + {1'b0, m};
          cycle_counter = 6'd0;
          // Initialize arrays; only initialize the used range [0 : n+m-1]
          for (integer i = 0; i < 32; i = i + 1) begin
            parent[i] = 5'b0;
            rank[i]   = 4'b0;
          end
          for (integer i = 0; i < 32; i = i + 1) begin
            if (i < {1'b0, n} + {1'b0, m}) begin
              parent[i] = 5'(i);
              rank[i]   = 4'd0;
            end else begin
              parent[i] = 5'd0;  // don't-care; keep known value
              rank[i]   = 4'd0;  // don't-care; keep known value
            end
          end
          ns = PROCESS;
        end else begin
          ns = IDLE;
        end
      end

      PROCESS: begin
        // Process exactly 32 elements or until q if q < 32; done after 32 cycles + 2 overhead (total 34)
        if (cycle_counter < 32) begin
          if (cycle_counter < {1'b0, q}) begin
            wire [4:0] r_in;
            wire [4:0] c_in;
            wire [4:0] idx_r;
            wire [4:0] idx_c;
            wire       valid_r;
            wire       valid_c;
            wire       valid_edge;

            assign r_in = elements[cycle_counter][9:5];  // row part
            assign c_in = elements[cycle_counter][4:0];  // col part
            assign idx_r = r_in;
            assign idx_c = {1'b0, n} + c_in;
            assign valid_r = (r_in < n);
            assign valid_c = (c_in < m);
            assign valid_edge = valid_r && valid_c;

            if (valid_edge) begin
              union_find(idx_r, idx_c);
            end
          end
          cycle_counter = cycle_counter + 1;
          ns = PROCESS;
        end else if (cycle_counter == 32) begin
          // Finalize result after processing 32 elements
          minimal_purchases = (total_components > 0) ? (total_components - 1) : 6'd0;
          done = 1'b1;
          cycle_counter = cycle_counter + 1;
          ns = DONE;
        end else begin
          // cycle_counter == 33: hold done high and wait 1 more cycle (34 total)
          minimal_purchases = (total_components > 0) ? (total_components - 1) : 6'd0;
          done = 1'b1;
          cycle_counter = 6'd34;
          ns = DONE;
        end
      end

      DONE: begin
        // Stay done until start toggles; maintain outputs
        done = 1'b1;
        // Keep minimal_purchases from previous cycle; no need to reassign
        if (start) begin
          ns = DONE;  // remain done while start is held
        end else begin
          ns = DONE;
        end
      end

      default: begin
        ns = IDLE;
        done = 1'b0;
      end
    endcase
  end

endmodule
