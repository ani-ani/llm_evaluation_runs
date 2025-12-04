module evenland_solution(
  input clk,
  input rst_n,
  input start,
  input [2:0] n,
  input [3:0] m,
  input [89:0] edges,
  output reg [29:0] way,
  output reg done
);

localparam logic [29:0] POWER2_MOD_LUT[16] = '{
  30'd1, 30'd2, 30'd4, 30'd8, 30'd16, 30'd32, 30'd64, 30'd128, 
  30'd256, 30'd512, 30'd1024, 30'd2048, 30'd4096, 30'd8192, 30'd16384, 30'd32768
};

typedef enum logic [2:0] {
  IDLE,
  UNPACK,
  GAUSS,
  CALC,
  DONE
} state_t;

state_t state;
reg [14:0] matrix[0:7];
reg [2:0] current_pivot;
reg [3:0] rank;
reg [3:0] exponent;
reg [2:0] n_reg;
reg [3:0] m_reg;
reg [2:0] pivot_row;
reg [3:0] pivot_col;
reg pivot_found;
integer c, r;

always_ff @(posedge clk or negedge rst_n) begin
  if (!rst_n) begin
    state <= IDLE;
    done <= 1'b0;
    way <= 30'd0;
    for (int i=0; i<8; i++) matrix[i] <= 15'd0;
    current_pivot <= 3'd0;
    rank <= 4'd0;
    n_reg <= 3'd0;
    m_reg <= 4'd0;
  end else begin
    case (state)
      IDLE: begin
        done <= 1'b0;
        if (start) begin
          n_reg <= n;
          m_reg <= m;
          state <= UNPACK;
          for (int i=0; i<8; i++) matrix[i] <= 15'd0;
        end
      end
      
      UNPACK: begin
        for (int j=0; j<15; j++) begin
          if (j < m_reg) begin
            logic [2:0] node_a = edges[6*j+5 -:3] - 3'd1;
            logic [2:0] node_b = edges[6*j+2 -:3] - 3'd1;
            matrix[node_a][j] <= 1'b1;
            matrix[node_b][j] <= 1'b1;
          end
        end
        current_pivot <= 3'd0;
        rank <= 4'd0;
        state <= GAUSS;
      end
      
      GAUSS: begin
        if (current_pivot < n_reg) begin
          pivot_found <= 1'b0;
          pivot_col <= 4'd0;
          pivot_row <= current_pivot;
          
          for (c=0; c<m_reg; c=c+1) begin
            if (!pivot_found) begin
              for (r=current_pivot; r<n_reg; r=r+1) begin
                if (matrix[r][c] && !pivot_found) begin
                  pivot_col <= c;
                  pivot_row <= r;
                  pivot_found <= 1'b1;
                end
              end
            end
          end
          
          if (pivot_found) begin
            matrix[current_pivot] <= matrix[pivot_row];
            matrix[pivot_row] <= matrix[current_pivot];
            
            for (r=current_pivot+1; r<n_reg; r=r+1) begin
              if (matrix[r][pivot_col]) begin
                matrix[r] <= matrix[r] ^ matrix[current_pivot];
              end
            end
            
            rank <= rank + 4'd1;
          end
          
          current_pivot <= current_pivot + 3'd1;
        end else begin
          state <= CALC;
        end
      end
      
      CALC: begin
        exponent <= m_reg - rank;
        state <= DONE;
      end
      
      DONE: begin
        way <= POWER2_MOD_LUT[exponent];
        done <= 1'b1;
        state <= IDLE;
      end
    endcase
  end
end

endmodule