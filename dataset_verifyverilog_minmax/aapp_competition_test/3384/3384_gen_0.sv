module handsome_number_finder(
  input reg clk,
  input reg rst_n,
  input reg start,
  input reg [13:0] num_in,
  output reg [13:0] result1,
  output reg [13:0] result2,
  output reg valid,
  output reg tie_flag
);

// Internal signals
localparam IDLE = 2'b00;
localparam SEARCH = 2'b01;
localparam DONE = 2'b10;

reg [1:0] state;
reg [6:0] offset_up, offset_down, cycle_cnt;
reg found_up, found_down;
reg [13:0] res_up, res_down;

// Handsome number checker function
function bit is_handsome (input [13:0] n);
    integer d0, d1, d2, d3;
    integer digits;
    bit cond;
    d0 = n % 10;
    d1 = (n / 10) % 10;
    d2 = (n / 100) % 10;
    d3 = (n / 1000) % 10;
    if (n <= 9) digits = 1;
    else if (n <= 99) digits = 2;
    else if (n <= 999) digits = 3;
    else digits = 4;
    case (digits)
        1: cond = 1'b1;
        2: cond = (d0 % 2) != (d1 % 2);
        3: cond = (d0 % 2) != (d1 % 2) && (d1 % 2) != (d2 % 2);
        4: cond = (d0 % 2) != (d1 % 2) && (d1 % 2) != (d2 % 2) && (d2 % 2) != (d3 % 2);
        default: cond = 1'b0;
    endcase
    is_handsome = cond;
endfunction

// State machine
always @(posedge clk, negedge rst_n) begin
    if (!rst_n) begin
        state <= IDLE;
        offset_up <= 7'b0;
        offset_down <= 7'b0;
        cycle_cnt <= 7'b0;
        found_up <= 1'b0;
        found_down <= 1'b0;
        res_up <= 14'b0;
        res_down <= 14'b0;
        result1 <= 14'b0;
        result2 <= 14'b0;
        valid <= 1'b0;
        tie_flag <= 1'b0;
    end else begin
        case (state)
            IDLE: begin
                offset_up <= 7'b0;
                offset_down <= 7'b0;
                cycle_cnt <= 7'b0;
                found_up <= 1'b0;
                found_down <= 1'b0;
                res_up <= 14'b0;
                res_down <= 14'b0;
                valid <= 1'b0;
                tie_flag <= 1'b0;
                if (start) state <= SEARCH;
            end
            SEARCH: begin
                // Check upward candidate
                if (!found_up) begin
                    if (num_in + offset_up <= 14'h9999 && is_handsome(num_in + offset_up)) begin
                        found_up <= 1'b1;
                        res_up <= num_in + offset_up;
                    end
                end
                // Check downward candidate
                if (!found_down) begin
                    if (num_in >= offset_down && is_handsome(num_in - offset_down)) begin
                        found_down <= 1'b1;
                        res_down <= num_in - offset_down;
                    end
                end
                // Increment offsets
                if (!found_up) offset_up <= offset_up + 1;
                if (!found_down) offset_down <= offset_down + 1;
                // Increment cycle counter
                cycle_cnt <= cycle_cnt + 1;
                // Decision to finish (allow up to 120 cycles to cover worst case)
                if ((found_up && found_down) || (cycle_cnt == 7'd120)) begin
                    // Compute final results
                    if (!found_up && !found_down) begin
                        result1 <= num_in;
                        result2 <= 14'b0;
                        tie_flag <= 1'b0;
                    end else if (found_up && !found_down) begin
                        result1 <= res_up;
                        result2 <= 14'b0;
                        tie_flag <= 1'b0;
                    end else if (!found_up && found_down) begin
                        result1 <= res_down;
                        result2 <= 14'b0;
                        tie_flag <= 1'b0;
                    end else begin
                        // Both found
                        if ((res_up - num_in) < (num_in - res_down)) begin
                            result1 <= res_up;
                            result2 <= 14'b0;
                            tie_flag <= 1'b0;
                        end else if ((res_up - num_in) > (num_in - res_down)) begin
                            result1 <= res_down;
                            result2 <= 14'b0;
                            tie_flag <= 1'b0;
                        end else begin
                            // Equal distance => tie
                            if (res_down < res_up) begin
                                result1 <= res_down;
                                result2 <= res_up;
                            end else begin
                                result1 <= res_up;
                                result2 <= res_down;
                            end
                            tie_flag <= 1'b1;
                        end
                    end
                    valid <= 1'b1;
                    state <= DONE;
                end else begin
                    state <= SEARCH;
                end
            end
            DONE: begin
                // Hold results
                valid <= 1'b1;
                state <= DONE;
            end
        endcase
    end
end

endmodule