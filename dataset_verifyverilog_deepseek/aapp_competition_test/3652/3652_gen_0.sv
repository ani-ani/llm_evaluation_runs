module minimal_column_deletion (
  input clk,
  input rst_n,
  input start,
  input [2:0] n,
  input [23:0] row1,
  input [23:0] row2,
  input [23:0] row3,
  output reg [3:0] result,
  output reg done
);

  typedef enum {IDLE, INIT, PROCESS_MASK, DONE} state_t;
  state_t current_state;

  reg [7:0] mask_counter;
  reg [3:0] max_kept;
  wire [3:0] cols_kept;
  wire is_valid;

  // Popcount calculation
  always_comb begin
    cols_kept = 0;
    for (int i=0; i<8; i++) begin
      if ((i < n) && mask_counter[i]) cols_kept++;
    end
  end

  // Sorting function with 19-stage network
  function automatic [31:0] sort8(input [31:0] data_in);
    reg [3:0] arr [0:7];
    reg [3:0] temp;
    begin
      for (int i=0; i<8; i++) arr[i] = data_in[(7-i)*4 +:4];

      // Stage 1
      if (arr[0] > arr[1]) begin temp=arr[0]; arr[0]=arr[1]; arr[1]=temp; end
      if (arr[2] > arr[3]) begin temp=arr[2]; arr[2]=arr[3]; arr[3]=temp; end
      if (arr[4] > arr[5]) begin temp=arr[4]; arr[4]=arr[5]; arr[5]=temp; end
      if (arr[6] > arr[7]) begin temp=arr[6]; arr[6]=arr[7]; arr[7]=temp; end
      // Stage 2
      if (arr[0] > arr[2]) begin temp=arr[0]; arr[0]=arr[2]; arr[2]=temp; end
      if (arr[1] > arr[3]) begin temp=arr[1]; arr[1]=arr[3]; arr[3]=temp; end
      if (arr[4] > arr[6]) begin temp=arr[4]; arr[4]=arr[6]; arr[6]=temp; end
      if (arr[5] > arr[7]) begin temp=arr[5]; arr[5]=arr[7]; arr[7]=temp; end
      // Stage 3
      if (arr[1] > arr[2]) begin temp=arr[1]; arr[1]=arr[2]; arr[2]=temp; end
      if (arr[5] > arr[6]) begin temp=arr[5]; arr[5]=arr[6]; arr[6]=temp; end
      if (arr[0] > arr[4]) begin temp=arr[0]; arr[0]=arr[4]; arr[4]=temp; end
      if (arr[3] > arr[7]) begin temp=arr[3]; arr[3]=arr[7]; arr[7]=temp; end
      // Stage 4
      if (arr[1] > arr[5]) begin temp=arr[1]; arr[1]=arr[5]; arr[5]=temp; end
      if (arr[2] > arr[6]) begin temp=arr[2]; arr[2]=arr[6]; arr[6]=temp; end
      // Stage 5
      if (arr[1] > arr[4]) begin temp=arr[1]; arr[1]=arr[4]; arr[4]=temp; end
      if (arr[3] > arr[6]) begin temp=arr[3]; arr[3]=arr[6]; arr[6]=temp; end
      // Stage 6
      if (arr[2] > arr[4]) begin temp=arr[2]; arr[2]=arr[4]; arr[4]=temp; end
      if (arr[3] > arr[5]) begin temp=arr[3]; arr[3]=arr[5]; arr[5]=temp; end
      // Stage 7
      if (arr[3] > arr[4]) begin temp=arr[3]; arr[3]=arr[4]; arr[4]=temp; end

      sort8 = {arr[0], arr[1], arr[2], arr[3], arr[4], arr[5], arr[6], arr[7]};
    end
  endfunction

  // Validation logic
  wire [31:0] sorted_row1, sorted_row2, sorted_row3;
  reg [3:0] row1_padded[0:7], row2_padded[0:7], row3_padded[0:7];
  wire [31:0] packed_row1 = {row1_padded[0], row1_padded[1], row1_padded[2], row1_padded[3],
                             row1_padded[4], row1_padded[5], row1_padded[6], row1_padded[7]};
  wire [31:0] packed_row2 = {row2_padded[0], row2_padded[1], row2_padded[2], row2_padded[3],
                             row2_padded[4], row2_padded[5], row2_padded[6], row2_padded[7]};
  wire [31:0] packed_row3 = {row3_padded[0], row3_padded[1], row3_padded[2], row3_padded[3],
                             row3_padded[4], row3_padded[5], row3_padded[6], row3_padded[7]};

  // Data padding
  always_comb begin
    for (int i=0; i<8; i++) begin
      if (i < n) begin
        row1_padded[i] = mask_counter[i] ? {1'b0, row1[i*3 +:3]} : 4'b1001;
        row2_padded[i] = mask_counter[i] ? {1'b0, row2[i*3 +:3]} : 4'b1001;
        row3_padded[i] = mask_counter[i] ? {1'b0, row3[i*3 +:3]} : 4'b1001;
      end else begin
        row1_padded[i] = 4'b1001;
        row2_padded[i] = 4'b1001;
        row3_padded[i] = 4'b1001;
      end
    end
  end

  assign sorted_row1 = sort8(packed_row1);
  assign sorted_row2 = sort8(packed_row2);
  assign sorted_row3 = sort8(packed_row3);

  // Comparison logic
  wire [7:0] match_bits;
  genvar k;
  generate
    for (k=0; k<8; k++) begin : match_gen
      wire [3:0] r1 = sorted_row1[(7-k)*4 +:4];
      wire [3:0] r2 = sorted_row2[(7-k)*4 +:4];
      wire [3:0] r3 = sorted_row3[(7-k)*4 +:4];
      assign match_bits[k] = (r1 == r2) && (r2 == r3);
    end
  endgenerate

  reg [8:0] match_accum;
  always_comb begin
    match_accum[0] = 1'b1;
    for (int j=0; j<8; j++) begin
      match_accum[j+1] = match_accum[j] && match_bits[j];
    end
  end

  assign is_valid = (cols_kept == 0) ? 1'b1 : match_accum[cols_kept];

  // FSM controller
  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      current_state <= IDLE;
      mask_counter <= 8'd0;
      max_kept <= 4'd0;
      result <= 4'd0;
      done <= 1'b0;
    end else begin
      case (current_state)
        IDLE: begin
          if (start) current_state <= INIT;
          done <= 1'b0;
        end
        INIT: begin
          mask_counter <= 8'd0;
          max_kept <= 4'd0;
          current_state <= PROCESS_MASK;
        end
        PROCESS_MASK: begin
          mask_counter <= mask_counter + 1;
          if ((cols_kept > max_kept) && is_valid) max_kept <= cols_kept;
          if (mask_counter == ((1 << n) - 1)) current_state <= DONE;
          else current_state <= PROCESS_MASK;
        end
        DONE: begin
          result <= n - max_kept;
          done <= 1'b1;
          if (start) current_state <= INIT;
          else current_state <= DONE;
        end
      endcase
    end
  end

endmodule