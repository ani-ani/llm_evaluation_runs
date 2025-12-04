module lex_order_solver (
  input clk,
  input rst_n,
  input start,
  input [2:0] L,
  input [2:0] N,
  input [191:0] words,
  output reg done,
  output reg [1:0] status,
  output reg [23:0] order
);

  typedef enum logic [2:0] {IDLE, EDGE_DETECT, INIT_TOPO, KAHN_LOOP, OUTPUT} state_t;
  state_t current_state;
  
  reg [7:0][7:0][2:0] word_array;
  reg [7:0][7:0] adj_matrix;
  reg [2:0] in_degree [0:7];
  reg [7:0] queue;
  reg [2:0] topo_order [0:7];
  reg [3:0] topo_count;
  reg [3:0] cycles;
  reg impossible;
  reg ambiguous;
  reg [191:0] words_reg;

  always_comb begin
    for (int i=0; i<8; i++) begin
      for (int j=0; j<8; j++) begin
        word_array[i][j] = words_reg[(191 - (i*24 + j*3)) -: 3];
      end
    end
  end

  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      current_state <= IDLE;
      done <= 0;
      status <= 0;
      order <= 0;
      impossible <= 0;
      ambiguous <= 0;
      adj_matrix <= 0;
      queue <= 0;
      cycles <= 0;
      topo_count <= 0;
      words_reg <= 0;
      for (int i=0; i<8; i++) topo_order[i] <= 0;
      for (int i=0; i<8; i++) in_degree[i] <= 0;
    end else begin
      done <= 0;
      case (current_state)
        IDLE: begin
          impossible <= 0;
          ambiguous <= 0;
          adj_matrix <= 0;
          cycles <= 0;
          topo_count <= 0;
          if (start) begin
            words_reg <= words;
            current_state <= EDGE_DETECT;
          end
        end
        
        EDGE_DETECT: begin
          impossible <= 0;
          for (int i=0; i < (N > 1 ? N-1 : 0); i++) begin
            bit found = 0;
            for (int j=0; j<8; j++) begin
              if (!found) begin
                if (word_array[i][j] != word_array[i+1][j]) begin
                  found = 1;
                  if (word_array[i][j] > word_array[i+1][j]) begin
                    impossible <= 1;
                  end else if (word_array[i][j] <= L && word_array[i+1][j] <= L) begin
                    adj_matrix[word_array[i][j]][word_array[i+1][j]] <= 1;
                  end
                end
              end
            end
          end
          current_state <= INIT_TOPO;
        end
        
        INIT_TOPO: begin
          queue <= 0;
          for (int node=0; node<=7; node++) begin
            in_degree[node] <= 0;
            if (node <= L) begin
              for (int src=0; src<=7; src++) begin
                if (src <= L && adj_matrix[src][node]) begin
                  in_degree[node] <= in_degree[node] + 1;
                end
              end
              if (in_degree[node] == 0) queue[node] <= 1;
            end
          end
          cycles <= 0;
          topo_count <= 0;
          ambiguous <= 0;
          current_state <= KAHN_LOOP;
        end
        
        KAHN_LOOP: begin
          if (cycles < (L+1)) begin
            if (queue != 0) begin
              // Count nodes in queue
              int count = 0;
              for (int i=0; i<=L; i++) count += queue[i];
              if (count > 1) ambiguous <= 1;

              // Dequeue lowest index
              for (int i=0; i<=L; i++) begin
                if (queue[i]) begin
                  topo_order[topo_count] <= i;
                  topo_count <= topo_count + 1;
                  queue[i] <= 0;
                  // Update neighbors
                  for (int j=0; j<=L; j++) begin
                    if (adj_matrix[i][j]) begin
                      in_degree[j] <= in_degree[j] - 1;
                      if (in_degree[j] == 0) queue[j] <= 1;
                    end
                  end
                  break;
                end
              end
            end
            cycles <= cycles + 1;
          end else begin
            current_state <= OUTPUT;
          end
        end
        
        OUTPUT: begin
          order <= 0;
          if (impossible || (topo_count != (L+1))) begin
            status <= 2'b01;
          end else if (ambiguous) begin
            status <= 2'b10;
          end else begin
            status <= 2'b00;
            for (int i=0; i<8; i++) begin
              if (i < (L+1)) order[23-3*i -: 3] <= topo_order[i];
              else order[23-3*i -: 3] <= 3'b0;
            end
          end
          done <= 1;
          current_state <= IDLE;
        end
      endcase
    end
  end
endmodule