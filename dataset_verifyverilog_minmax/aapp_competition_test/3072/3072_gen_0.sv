module max_table_perimeter(
  input clk,
  input rst_n,
  input start,
  input [63:0] grid_flat, // Flattened grid (row-major: grid_flat[7:0]=row0, 0=free, 1=blocked
  output reg [5:0] max_perimeter,
  output reg done
);

  // State machine states
  typedef enum logic [1:0] { IDLE = 2'b00, CALC = 2'b01, DONE = 2'b10 } state_t;
  state_t state, next_state;

  // Iteration counters (12-bit to count 0..4095)
  logic [11:0] cnt, cnt_next;
  // Rectangle coordinates
  logic [2:0] i_r, j_r, k_r, l_r;
  logic [2:0] i_next, j_next, k_next, l_next;
  logic last_rect;
  logic all_free_d, all_free_d_next;
  logic [5:0] rect_perimeter, rect_perimeter_next;

  // Update current rectangle coordinates from cnt
  function [11:0] decode_index(input [11:0] idx);
    // idx = (((i*8) + k)*8 + j)*8 + l  (i,k,j,l in 0..7)
    decode_index = idx;
  endfunction

  function [2:0] get_i(input [11:0] idx);
    get_i = idx / 512; // 8*8*8 = 512
  endfunction

  function [2:0] get_k(input [11:0] idx);
    get_k = (idx / 64) % 8; // 8*8 = 64
  endfunction

  function [2:0] get_j(input [11:0] idx);
    get_j = (idx / 8) % 8;
  endfunction

  function [2:0] get_l(input [11:0] idx);
    get_l = idx % 8;
  endfunction

  // Check if rectangle (i..k, j..l) is all free (0)
  function is_rect_free(input [2:0] i, k, j, l, input [63:0] g);
    integer r, c;
    reg ok;
    ok = 1'b1;
    for (r = i; r <= k; r = r + 1) begin
      for (c = j; c <= l; c = c + 1) begin
        if (g[(r * 8) + c]) ok = 1'b0; // 1 = blocked
      end
    end
    is_rect_free = ok;
  endfunction

  // Compute perimeter: 2*((h+w)-0.5) = 2*(h+w) - 1
  function [5:0] rect_perimeter_calc(input [2:0] i, k, j, l);
    logic [3:0] h, w;
    h = (k - i) + 1;
    w = (l - j) + 1;
    rect_perimeter_calc = (2 * (h + w)) - 1;
  endfunction

  // Sequential logic
  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state <= IDLE;
      cnt <= 12'd0;
      max_perimeter <= 6'd0;
      done <= 1'b0;
      i_r <= 3'd0;
      j_r <= 3'd0;
      k_r <= 3'd0;
      l_r <= 3'd0;
      all_free_d <= 1'b0;
      rect_perimeter <= 6'd0;
    end else begin
      state <= next_state;
      cnt <= cnt_next;
      i_r <= i_next;
      j_r <= j_next;
      k_r <= k_next;
      l_r <= l_next;
      all_free_d <= all_free_d_next;
      rect_perimeter <= rect_perimeter_next;
      // Registered outputs
      if (state == CALC) begin
        if (all_free_d_next) begin
          if (rect_perimeter_next > max_perimeter)
            max_perimeter <= rect_perimeter_next;
        end
      end
      done <= (next_state == DONE);
    end
  end

  // Combinational next-state logic
  always_comb begin
    // Defaults
    next_state = state;
    cnt_next = cnt;
    i_next = i_r;
    j_next = j_r;
    k_next = k_r;
    l_next = l_r;
    all_free_d_next = 1'b0;
    rect_perimeter_next = 6'd0;

    case (state)
      IDLE: begin
        cnt_next = 12'd0;
        if (start) begin
          // Initialize with first rect (i=0,k=0,j=0,l=0)
          i_next = 3'd0;
          k_next = 3'd0;
          j_next = 3'd0;
          l_next = 3'd0;
          all_free_d_next = is_rect_free(3'd0, 3'd0, 3'd0, 3'd0, grid_flat);
          rect_perimeter_next = rect_perimeter_calc(3'd0, 3'd0, 3'd0, 3'd0);
          next_state = CALC;
        end else begin
          next_state = IDLE;
        end
      end

      CALC: begin
        // Update coordinates for current cnt
        i_next = get_i(cnt);
        k_next = get_k(cnt);
        j_next = get_j(cnt);
        l_next = get_l(cnt);
        all_free_d_next = is_rect_free(i_next, k_next, j_next, l_next, grid_flat);
        rect_perimeter_next = rect_perimeter_calc(i_next, k_next, j_next, l_next);

        if (cnt == 12'd4095) begin
          // Last rectangle processed; go to DONE
          next_state = DONE;
        end
        cnt_next = cnt + 1;
      end

      DONE: begin
        // Stay DONE for exactly 1 cycle, then return to IDLE
        next_state = IDLE;
      end

      default: next_state = IDLE;
    endcase
  end

endmodule
