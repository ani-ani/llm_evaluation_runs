module max_xor_subset (
  input clk,
  input rst_n,
  input start,
  input [2:0] num_count,
  input [31:0] data_in,
  input data_valid,
  output reg [31:0] result,
  output reg done,
  output reg busy
);

  // State definitions
  localparam [2:0] IDLE = 3'b000;
  localparam [2:0] COLLECT = 3'b001;
  localparam [2:0] BUILD_BASIS = 3'b010;
  localparam [2:0] MAXIMIZE = 3'b011;
  localparam [2:0] DONE = 3'b100;

  reg [2:0] state = IDLE;
  reg [2:0] current_state = IDLE;
  reg [2:0] next_state = IDLE;

  // Internal registers
  reg [31:0] buffer [0:7]; // Input buffer
  reg [31:0] basis [0:7]; // Basis vectors
  reg [2:0] buffer_idx = 0; // Current buffer index
  reg [2:0] basis_idx = 0; // Current basis index
  reg [2:0] num_idx = 0; // Current number index
  reg [2:0] max_idx = 0; // Current maximization index
  reg [31:0] current_num = 0; // Current number being processed
  reg [31:0] temp_result = 0; // Temporary result during maximization

  // Initialize basis to zero
  integer i;
  initial begin
    for (i = 0; i < 8; i = i + 1) begin
      basis[i] = 0;
    end
  end

  // State machine
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state <= IDLE;
      busy <= 1'b0;
      done <= 1'b0;
      result <= 32'b0;
      buffer_idx <= 0;
      basis_idx <= 0;
      num_idx <= 0;
      max_idx <= 0;
      current_num <= 0;
      temp_result <= 0;
      for (i = 0; i < 8; i = i + 1) begin
        buffer[i] <= 0;
        basis[i] <= 0;
      end
    end else begin
      state <= next_state;
      busy <= (state != IDLE && state != DONE);
      done <= (state == DONE);
    end
  end

  // Next state logic
  always @(*) begin
    next_state = state;
    case (state)
      IDLE: begin
        if (start) begin
          next_state = COLLECT;
        end
      end
      COLLECT: begin
        if (buffer_idx == num_count - 1 && data_valid) begin
          next_state = BUILD_BASIS;
        end
      end
      BUILD_BASIS: begin
        if (num_idx == num_count - 1 && basis_idx == 7) begin
          next_state = MAXIMIZE;
        end
      end
      MAXIMIZE: begin
        if (max_idx == 7) begin
          next_state = DONE;
        end
      end
      DONE: begin
        if (!start) begin
          next_state = IDLE;
        end
      end
      default: next_state = IDLE;
    endcase
  end

  // Data collection
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      buffer_idx <= 0;
    end else if (state == COLLECT && data_valid) begin
      buffer[buffer_idx] <= data_in;
      buffer_idx <= buffer_idx + 1;
    end
  end

  // Build basis
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      num_idx <= 0;
      basis_idx <= 0;
      current_num <= 0;
    end else if (state == BUILD_BASIS) begin
      if (basis_idx == 0) begin
        current_num <= buffer[num_idx];
      end
      if (current_num != 0) begin
        if (basis_idx < 8 && basis[basis_idx] == 0) begin
          basis[basis_idx] <= current_num;
          basis_idx <= basis_idx + 1;
        end else if (basis_idx < 8) begin
          if (current_num[31] == basis[basis_idx][31]) begin
            current_num <= current_num ^ basis[basis_idx];
          end
          basis_idx <= basis_idx + 1;
        end else begin
          basis_idx <= 0;
          num_idx <= num_idx + 1;
        end
      end else begin
        basis_idx <= 0;
        num_idx <= num_idx + 1;
      end
    end
  end

  // Maximize
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      max_idx <= 0;
      temp_result <= 0;
    end else if (state == MAXIMIZE) begin
      if (max_idx == 0) begin
        temp_result <= 0;
      end
      if (max_idx < 8 && basis[max_idx] != 0) begin
        if ((temp_result ^ basis[max_idx]) > temp_result) begin
          temp_result <= temp_result ^ basis[max_idx];
        end
        max_idx <= max_idx + 1;
      end else if (max_idx == 8) begin
        result <= temp_result;
      end
    end
  end

endmodule