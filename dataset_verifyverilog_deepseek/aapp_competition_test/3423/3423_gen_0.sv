module package_dependency_solver #(parameter P = 8)(
  input clk,
  input rst_n,
  input start,
  input [2:0] num_pkgs,
  input [P-1:0][P-1:0] dep_matrix,
  input [P-1:0][2:0] pkg_ids,
  output reg [2:0] order [0:P-1],
  output reg done,
  output reg valid
);
  
  localparam IDLE = 2'b00;
  localparam PROCESSING = 2'b01;
  localparam DONE = 2'b10;
  
  reg [1:0] state, next_state;
  reg [3:0] in_degree [0:P-1];
  reg [P-1:0] remaining;
  reg [2:0] count;
  
  wire found;
  reg [2:0] selected_pkg;
  wire [2:0] min_id;
  
  assign min_id = 3'b111;
  
  integer i, j;
  
  always_comb begin
    found = 1'b0;
    selected_pkg = 0;
    if (state == PROCESSING) begin
      for (i = 0; i < P; i++) begin
        if (remaining[i] && !in_degree[i]) begin
          found = 1'b1;
          if (pkg_ids[i] < min_id) begin
            selected_pkg = i;
          end
        end
      end
    end
  end
  
  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state <= IDLE;
      done <= 1'b0;
      valid <= 1'b0;
      count <= 0;
      remaining <= '0;
      for (i = 0; i < P; i++) begin
        in_degree[i] <= 4'b0;
        order[i] <= 3'b0;
      end
    end else begin
      case(state)
        IDLE: begin
          done <= 1'b0;
          valid <= 1'b0;
          if (start) begin
            remaining <= '0;
            for (i = 0; i < P; i++) begin
              if (i < num_pkgs) begin
                remaining[i] <= 1'b1;
                in_degree[i] <= 4'b0;
                for (j = 0; j < num_pkgs; j++) begin
                  in_degree[i] <= in_degree[i] + dep_matrix[i][j];
                end
              end else begin
                remaining[i] <= 1'b0;
                in_degree[i] <= 4'b0;
              end
            end
            count <= 0;
            state <= PROCESSING;
          end
        end
        
        PROCESSING: begin
          if (found) begin
            order[count] <= pkg_ids[selected_pkg];
            remaining[selected_pkg] <= 1'b0;
            for (j = 0; j < P; j++) begin
              if (remaining[j] && dep_matrix[j][selected_pkg]) begin
                in_degree[j] <= in_degree[j] - 1;
              end
            end
            if (count == num_pkgs - 1) begin
              valid <= 1'b1;
              done <= 1'b1;
              state <= DONE;
            end else begin
              count <= count + 1;
            end
          end else begin
            valid <= 1'b0;
            done <= 1'b1;
            state <= DONE;
          end
        end
        
        DONE: begin
          if (!start) begin
            state <= IDLE;
            done <= 1'b0;
          end
        end
      endcase
    end
  end
endmodule