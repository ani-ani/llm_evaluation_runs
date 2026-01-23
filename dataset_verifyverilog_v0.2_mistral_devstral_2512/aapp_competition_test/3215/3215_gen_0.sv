module card_shuffle_counter (
  input clk,
  input rst_n,
  input start,
  input [3:0] card_in,
  input valid,
  output reg [1:0] result,
  output reg done
);

  // State definitions
  typedef enum logic [2:0] {
    IDLE,
    COLLECT,
    CHECK_0,
    CHECK_1,
    CHECK_2,
    DONE
  } state_t;

  state_t current_state, next_state;

  // Card buffer (8 cards, 4 bits each)
  reg [3:0] card_buffer [0:7];
  reg [2:0] card_count;

  // Internal signals
  reg [1:0] shuffle_count;
  reg is_sorted;
  reg is_one_shuffle;
  reg is_two_shuffles;

  // State machine
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      current_state <= IDLE;
      card_count <= 0;
      result <= 0;
      done <= 0;
    end else begin
      current_state <= next_state;
    end
  end

  // Next state logic
  always @(*) begin
    next_state = current_state;
    case (current_state)
      IDLE: begin
        if (start) next_state = COLLECT;
      end
      COLLECT: begin
        if (card_count == 7 && valid) next_state = CHECK_0;
      end
      CHECK_0: begin
        next_state = CHECK_1;
      end
      CHECK_1: begin
        next_state = CHECK_2;
      end
      CHECK_2: begin
        next_state = DONE;
      end
      DONE: begin
        if (start) next_state = COLLECT;
      end
    endcase
  end

  // Card collection
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      card_count <= 0;
    end else if (current_state == COLLECT && valid) begin
      card_buffer[card_count] <= card_in;
      card_count <= card_count + 1;
    end
  end

  // Check if sorted (0 shuffles)
  always @(*) begin
    is_sorted = 1;
    for (int i = 0; i < 7; i++) begin
      if (card_buffer[i] + 1 != card_buffer[i+1]) begin
        is_sorted = 0;
      end
    end
  end

  // Check if one shuffle achievable
  always @(*) begin
    is_one_shuffle = 0;
    for (int split = 0; split < 8; split++) begin
      reg [3:0] temp_buffer [0:7];
      int left_ptr = 0, right_ptr = split;
      
      // Simulate unshuffle
      for (int i = 0; i < 8; i++) begin
        if (i % 2 == 0 && left_ptr < split) begin
          temp_buffer[i] = card_buffer[left_ptr];
          left_ptr++;
        end else if (right_ptr < 8) begin
          temp_buffer[i] = card_buffer[right_ptr];
          right_ptr++;
        end
      end
      
      // Check if sorted
      reg sorted = 1;
      for (int j = 0; j < 7; j++) begin
        if (temp_buffer[j] + 1 != temp_buffer[j+1]) begin
          sorted = 0;
        end
      end
      
      if (sorted) begin
        is_one_shuffle = 1;
        break;
      end
    end
  end

  // Check if two shuffles achievable
  always @(*) begin
    is_two_shuffles = 0;
    for (int split1 = 0; split1 < 8; split1++) begin
      reg [3:0] temp_buffer1 [0:7];
      int left_ptr1 = 0, right_ptr1 = split1;
      
      // First unshuffle
      for (int i = 0; i < 8; i++) begin
        if (i % 2 == 0 && left_ptr1 < split1) begin
          temp_buffer1[i] = card_buffer[left_ptr1];
          left_ptr1++;
        end else if (right_ptr1 < 8) begin
          temp_buffer1[i] = card_buffer[right_ptr1];
          right_ptr1++;
        end
      end
      
      // Second unshuffle
      for (int split2 = 0; split2 < 8; split2++) begin
        reg [3:0] temp_buffer2 [0:7];
        int left_ptr2 = 0, right_ptr2 = split2;
        
        for (int i = 0; i < 8; i++) begin
          if (i % 2 == 0 && left_ptr2 < split2) begin
            temp_buffer2[i] = temp_buffer1[left_ptr2];
            left_ptr2++;
          end else if (right_ptr2 < 8) begin
            temp_buffer2[i] = temp_buffer1[right_ptr2];
            right_ptr2++;
          end
        end
        
        // Check if sorted
        reg sorted = 1;
        for (int j = 0; j < 7; j++) begin
          if (temp_buffer2[j] + 1 != temp_buffer2[j+1]) begin
            sorted = 0;
          end
        end
        
        if (sorted) begin
          is_two_shuffles = 1;
          break;
        end
      end
      
      if (is_two_shuffles) break;
    end
  end

  // Result and done logic
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      result <= 0;
      done <= 0;
    end else begin
      case (current_state)
        CHECK_0: begin
          if (is_sorted) shuffle_count = 0;
        end
        CHECK_1: begin
          if (!is_sorted && is_one_shuffle) shuffle_count = 1;
        end
        CHECK_2: begin
          if (!is_sorted && !is_one_shuffle && is_two_shuffles) shuffle_count = 2;
          else if (!is_sorted && !is_one_shuffle && !is_two_shuffles) shuffle_count = 3;
        end
        DONE: begin
          result <= shuffle_count;
          done <= 1;
        end
        default: begin
          result <= 0;
          done <= 0;
        end
      endcase
    end
  end

endmodule