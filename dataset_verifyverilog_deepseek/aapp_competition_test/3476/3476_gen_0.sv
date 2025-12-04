module matrix_optimizer(
  input clk, 
  input rst_n, 
  input start, 
  input signed [15:0] matrix_in [0:3][0:3], 
  output reg signed [31:0] best_sum, 
  output reg [2:0] operation_count, 
  output reg [127:0] operation_sequence
);
  
  reg signed [15:0] current_matrix [0:3][0:3];
  reg signed [31:0] current_sum;
  reg processing;
  reg [1:0] step;
  reg [2:0] op_count_next;
  reg [127:0] operation_seq_next;
  
  localparam OP_ROTR = 3'b000;
  localparam OP_ROTS = 3'b001;
  localparam OP_NEGR = 3'b010;
  localparam OP_NEGS = 3'b011;
  
  // Internal signals for operations
  wire signed [31:0] sums [0:19];
  wire [18:0] operations [0:19]; // {3-bit op, 16-bit args}
  
  // Generate all possible operations and their sums
  generate
    genvar i, j;
    // rotR operations
    for (i=0; i<4; i=i+1) begin : rotR_gen
      for (j=0; j<3; j=j+1) begin : shift_gen
        localparam idx = i*3 + j;
        // Operation encoding
        assign operations[idx] = {OP_ROTR, 2'(i), 2'(j+1), 12'b0};
        // Modified matrix
        signed [15:0] modified [0:3][0:3];
        integer r, c;
        always_comb begin
          for (r=0; r<4; r++) begin
            for (c=0; c<4; c++) begin
              modified[r][c] = (r == i) ? current_matrix[r][(c - (j+1)) % 4] : current_matrix[r][c];
            end
          end
        end
        assign sums[idx] = sum_matrix(modified);
      end
    end
    
    // rotS operations
    for (i=0; i<3; i=i+1) begin : rotS_gen
      localparam idx = 12 + i;
      assign operations[idx] = {OP_ROTS, 2'(i), 14'b0};
      signed [15:0] modified [0:3][0:3];
      integer r, c;
      always_comb begin
        for (r=0; r<4; r++) begin
          for (c=0; c<4; c++) begin
            case(i)
              0: modified[r][c] = current_matrix[3-c][r]; // 90°
              1: modified[r][c] = current_matrix[3-r][3-c]; // 180°
              2: modified[r][c] = current_matrix[c][3-r]; // 270°
            endcase
          end
        end
      end
      assign sums[idx] = sum_matrix(modified);
    end
    
    // negR operations
    for (i=0; i<4; i=i+1) begin : negR_gen
      localparam idx = 15 + i;
      assign operations[idx] = {OP_NEGR, 2'(i), 14'b0};
      signed [15:0] modified [0:3][0:3];
      integer r, c;
      always_comb begin
        for (r=0; r<4; r++) begin
          for (c=0; c<4; c++) begin
            modified[r][c] = (r == i) ? -current_matrix[r][c] : current_matrix[r][c];
          end
        end
      end
      assign sums[idx] = sum_matrix(modified);
    end
    
    // negS operation
    assign operations[19] = {OP_NEGS, 16'b0};
    signed [15:0] modified_negS [0:3][0:3];
    integer r, c;
    always_comb begin
      for (r=0; r<4; r++) begin
        for (c=0; c<4; c++) begin
          modified_negS[r][c] = -current_matrix[r][c];
        end
      end
    end
    assign sums[19] = sum_matrix(modified_negS);
  endgenerate
  
  function automatic signed [31:0] sum_matrix (input signed [15:0] matrix [0:3][0:3]);
    int i, j;
    sum_matrix = 0;
    for (i=0; i<4; i++) begin
      for (j=0; j<4; j++) begin
        sum_matrix += matrix[i][j];
      end
    end
  endfunction
  
  // Find max sum and index
  reg signed [31:0] max_sum;
  reg [4:0] max_idx;
  reg found;
  integer k;
  always_comb begin
    max_sum = current_sum;
    max_idx = 0;
    found = 0;
    for (k=0; k<20; k++) begin
      if (sums[k] > max_sum) begin
        max_sum = sums[k];
        max_idx = k;
        found = 1;
      end
    end
  end
  
  // Update sequence
  always @(posedge clk or negedge rst_n) begin
    if (~rst_n) begin
      operation_count <= 0;
      best_sum <= 0;
      operation_sequence <= 0;
      current_sum <= 0;
      processing <= 0;
      step <= 0;
      for (int i=0; i<4; i++) begin
        for (int j=0; j<4; j++) begin
          current_matrix[i][j] <= 0;
        end
      end
    end else begin
      if (start && ~processing) begin
        processing <= 1;
        step <= 1;
        op_count_next <= 0;
        operation_seq_next <= 0;
        // Initialize current_matrix
        for (int i=0; i<4; i++) begin
          for (int j=0; j<4; j++) begin
            current_matrix[i][j] <= matrix_in[i][j];
          end
        end
        current_sum <= sum_matrix(matrix_in);
      end else if (processing) begin
        if (step < 3) begin
          step <= step + 1;
        end else begin
          processing <= 0;
          step <= 0;
          best_sum <= current_sum;
          operation_count <= op_count_next;
          operation_sequence <= operation_seq_next;
        end
        
        if (found) begin
          current_sum <= max_sum;
          op_count_next <= (op_count_next < 5) ? op_count_next + 1 : op_count_next;
          operation_seq_next <= {operation_seq_next[108:0], operations[max_idx]};
          // Update current_matrix based on max_idx operation
          if (operations[max_idx][18:16] == OP_ROTR) begin
            int row = operations[max_idx][15:14];
            int shift = operations[max_idx][13:12];
            for (int c=0; c<4; c++) begin
              current_matrix[row][c] <= current_matrix[row][(c - shift) % 4];
            end
          end else if (operations[max_idx][18:16] == OP_ROTS) begin
            int rot_type = operations[max_idx][15:14];
            for (int r=0; r<4; r++) begin
              for (int c=0; c<4; c++) begin
                case(rot_type)
                  0: current_matrix[r][c] <= current_matrix[3-c][r];
                  1: current_matrix[r][c] <= current_matrix[3-r][3-c];
                  2: current_matrix[r][c] <= current_matrix[c][3-r];
                endcase
              end
            end
          end else if (operations[max_idx][18:16] == OP_NEGR) begin
            int row = operations[max_idx][15:14];
            for (int c=0; c<4; c++) begin
              current_matrix[row][c] <= -current_matrix[row][c];
            end
          end else if (operations[max_idx][18:16] == OP_NEGS) begin
            for (int r=0; r<4; r++) begin
              for (int c=0; c<4; c++) begin
                current_matrix[r][c] <= -current_matrix[r][c];
              end
            end
          end
        end
      end
    end
  end
endmodule