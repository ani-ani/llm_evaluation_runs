module sorted_array_kth_element(
  input clk,
  input rst_n,
  input start,
  input [2:0] arr1_len,
  input [2:0] arr2_len,
  input [9:0] arr1 [0:7],
  input [9:0] arr2 [0:7],
  input [3:0] k_in,
  output reg [9:0] kth_element,
  output reg done,
  output reg error
);
  
  typedef enum logic [2:0] {
    IDLE,
    COMPARE,
    CHECK_ARR1,
    CHECK_ARR2,
    DONE
  } fsm_state_t;
  
  fsm_state_t state;
  
  reg [2:0] arr1_len_r;
  reg [2:0] arr2_len_r;
  reg [3:0] k_in_r;
  reg [9:0] arr1_r [0:7];
  reg [9:0] arr2_r [0:7];
  reg [9:0] current_element;
  reg [2:0] i;
  reg [2:0] j;
  reg [3:0] count;
  reg [4:0] total_length_r;
  wire [9:0] selected_element;
  wire [3:0] count_next = count + 1;
  
  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state <= IDLE;
      done <= 0;
      error <= 0;
      kth_element <= 0;
      arr1_len_r <= 0;
      arr2_len_r <= 0;
      k_in_r <= 0;
      current_element <= 0;
      i <= 0;
      j <= 0;
      count <= 0;
      total_length_r <= 0;
      foreach(arr1_r[i]) arr1_r[i] <= 0;
      foreach(arr2_r[i]) arr2_r[i] <= 0;
    end else begin
      done <= 0;
      case (state)
        IDLE: begin
          if (start) begin
            error <= 0;
            arr1_len_r <= arr1_len;
            arr2_len_r <= arr2_len;
            k_in_r <= k_in;
            total_length_r <= arr1_len + arr2_len;
            foreach(arr1_r[i]) arr1_r[i] <= arr1[i];
            foreach(arr2_r[i]) arr2_r[i] <= arr2[i];
            if (k_in > (arr1_len + arr2_len)) begin
              error <= 1;
              done <= 1;
              state <= DONE;
            end else begin
              i <= 0;
              j <= 0;
              count <= 0;
              state <= COMPARE;
            end
          end
        end
        
        COMPARE: begin
          if (count == k_in_r) begin
            kth_element <= current_element;
            done <= 1;
            state <= DONE;
          end else begin
            if (i < arr1_len_r && j < arr2_len_r) begin
              if (arr1_r[i] <= arr2_r[j]) begin
                if (count_next == k_in_r) begin
                  kth_element <= arr1_r[i];
                  i <= i + 1;
                  count <= count_next;
                  done <= 1;
                  state <= DONE;
                end else begin
                  current_element <= arr1_r[i];
                  i <= i + 1;
                  count <= count_next;
                  state <= COMPARE;
                end
              end else begin
                if (count_next == k_in_r) begin
                  kth_element <= arr2_r[j];
                  j <= j + 1;
                  count <= count_next;
                  done <= 1;
                  state <= DONE;
                end else begin
                  current_element <= arr2_r[j];
                  j <= j + 1;
                  count <= count_next;
                  state <= COMPARE;
                end
              end
            end else if (i < arr1_len_r) begin
              state <= CHECK_ARR1;
            end else if (j < arr2_len_r) begin
              state <= CHECK_ARR2;
            end else begin
              error <= 1;
              done <= 1;
              state <= DONE;
            end
          end
        end
        
        CHECK_ARR1: begin
          if (count_next == k_in_r) begin
            kth_element <= arr1_r[i];
            i <= i + 1;
            count <= count_next;
            done <= 1;
            state <= DONE;
          end else begin
            current_element <= arr1_r[i];
            i <= i + 1;
            count <= count_next;
            state <= COMPARE;
          end
        end
        
        CHECK_ARR2: begin
          if (count_next == k_in_r) begin
            kth_element <= arr2_r[j];
            j <= j + 1;
            count <= count_next;
            done <= 1;
            state <= DONE;
          end else begin
            current_element <= arr2_r[j];
            j <= j + 1;
            count <= count_next;
            state <= COMPARE;
          end
        end
        
        DONE: begin
          done <= 1;
          state <= IDLE;
        end
      endcase
    end
  end

endmodule