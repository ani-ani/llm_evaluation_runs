module alice_bob_meet (
  input clk,
  input rst_n,
  input start,
  input [15:0] adjacency,
  input [1:0] alice_start,
  input [1:0] bob_start,
  output reg [31:0] expected_time,
  output reg done
);

  localparam IDLE   = 2'b00;
  localparam INIT   = 2'b01;
  localparam CALC   = 2'b10;
  localparam FINISH = 2'b11;

  reg [1:0] state;
  reg [3:0] cnt;
  reg [3:0] init_state;

  // internal registers
  reg [31:0] E[16];
  reg [31:0] E_next[16];
  reg [15:0] P[16][16];   // Q16.16 coefficients
  reg [31:0] p[4][4];     // Q16.16 single-walker transition probabilities
  reg [3:0] deg[4];
  reg [3:0] reachable;

  // adjacency rows for convenience
  wire [3:0] row[4];
  assign row[0] = adjacency[3:0];
  assign row[1] = adjacency[7:4];
  assign row[2] = adjacency[11:8];
  assign row[3] = adjacency[15:12];

  // reachability from alice_start (BFS up to 3 hops, enough for 4 nodes)
  wire [3:0] start_vec;
  assign start_vec = 4'b1 << alice_start;
  wire [3:0] r0, r1, r2, r3;
  assign r0 = start_vec;
  assign r1 = r0 | ((row[0] & {4{r0[0]}}) | (row[1] & {4{r0[1]}}) | (row[2] & {4{r0[2]}}) | (row[3] & {4{r0[3]}}));
  assign r2 = r1 | ((row[0] & {4{r1[0]}}) | (row[1] & {4{r1[1]}}) | (row[2] & {4{r1[2]}}) | (row[3] & {4{r1[3]}}));
  assign r3 = r2 | ((row[0] & {4{r2[0]}}) | (row[1] & {4{r2[1]}}) | (row[2] & {4{r2[2]}}) | (row[3] & {4{r2[3]}}));
  assign reachable = r3;
  wire disconnected;
  assign disconnected = (reachable & (4'b1 << bob_start)) == 0;

  // combinational logic: degrees, single‑walker probabilities, combined transition matrix, one Gauss‑Seidel iteration
  always_comb begin
     // degree of each node
     for (int i = 0; i < 4; i++) begin
        deg[i] = adjacency[4*i] + adjacency[4*i+1] + adjacency[4*i+2] + adjacency[4*i+3];
     end

     // initialize single‑walker transition matrix
     for (int i = 0; i < 4; i++) begin
        for (int j = 0; j < 4; j++) begin
           p[i][j] = 0;
        end
     end

     // set probabilities based on degree
     for (int i = 0; i < 4; i++) begin
        case (deg[i])
          4'd0: p[i][i] = 16'h10000;                // isolated node stays put
          4'd1: begin
             for (int j = 0; j < 4; j++) begin
                if (adjacency[4*i + j]) p[i][j] = 16'h10000;
             end
          end
          4'd2: begin
             for (int j = 0; j < 4; j++) begin
                if (adjacency[4*i + j]) p[i][j] = 16'h8000; // 0.5
             end
          end
          4'd3: begin
             for (int j = 0; j < 4; j++) begin
                if (adjacency[4*i + j]) p[i][j] = 16'h5555; // 1/3 truncated
             end
          end
          4'd4: begin
             for (int j = 0; j < 4; j++) begin
                if (adjacency[4*i + j]) p[i][j] = 16'h4000; // 0.25
             end
          end
          default: ;
        endcase
     end

     // combined transition matrix P for the 4×4=16 product states
     for (int i = 0; i < 16; i++) begin
        for (int j = 0; j < 16; j++) begin
           P[i][j] = 0;
        end
     end
     for (int i = 0; i < 16; i++) begin
        int a, b, c, d, t;
        a = i >> 2;
        b = i & 3;
        if (a == b) begin
           P[i][i] = 16'h10000; // absorbing state stays in itself
        end else begin
           for (c = 0; c < 4; c++) begin
              for (d = 0; d < 4; d++) begin
                 t = (c << 2) | d;
                 int prod;
                 prod = (p[a][c][15:0] * p[b][d][15:0]) >> 16; // Q16.16 * Q16.16 -> Q16.16
                 P[i][t] = prod[15:0];
              end
           end
        end
     end

     // Gauss‑Seidel iteration: compute new expected times
     for (int i = 0; i < 16; i++) begin
        int a, b;
        a = i >> 2;
        b = i & 3;
        if (a == b) begin
           E_next[i] = 0; // absorbing states have zero expected remaining time
        end else begin
           int sum;
           sum = 0;
           for (int j = 0; j < 16; j++) begin
              int val;
              // use updated E_next for j < i, otherwise previous E
              val = (j < i) ? E_next[j][15:0] : E[j][15:0];
              int term;
              term = (P[i][j] * val) >> 16;
              sum = sum + term;
           end
           E_next[i] = 16'h10000 + sum; // add one step
        end
     end
  end

  // state machine
  always_ff @(posedge clk or negedge rst_n) begin
     if (!rst_n) begin
        state <= IDLE;
        done <= 1'b0;
        expected_time <= 32'h0;
        cnt <= 4'b0;
        for (int i = 0; i < 16; i++) E[i] <= 0;
     end else begin
        case (state)
          IDLE: begin
             done <= 1'b0;
             if (start) begin
                state <= INIT;
                init_state <= {alice_start, bob_start}; // 4‑bit combined index
             end
          end
          INIT: begin
             if (disconnected) begin
                expected_time <= 32'hFFFFFFFF;
                state <= FINISH;
             end else begin
                cnt <= 0;
                state <= CALC;
             end
          end
          CALC: begin
             // perform one iteration
             for (int i = 0; i < 16; i++) E[i] <= E_next[i];
             cnt <= cnt + 1;
             if (cnt == 4'd12) begin // after 12 iterations (≤16 cycles total)
                expected_time <= E_next[init_state];
                state <= FINISH;
             end
          end
          FINISH: begin
             done <= 1'b1;
             if (!start) state <= IDLE;
          end
        endcase
     end
  end

endmodule