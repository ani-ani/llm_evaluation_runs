module gcd_operations_calculator (
    input clk,
    input rst_n,
    input start,
    input [7:0] a_0, a_1, a_2, a_3, a_4, a_5, a_6, a_7,
    output reg [7:0] result,
    output reg done
);

// Array storage
reg [7:0] arr [8];

// Count of ones
reg [7:0] count_ones;

// Total GCD
reg [7:0] total_gcd;

// For finding shortest subarray
reg [2:0] min_len;

// State machine registers
reg [2:0] state;
reg [2:0] current_index; // for computing total_gcd

// Function to compute GCD
function [7:0] gcd;
input [7:0] a, b;
begin
    if (b == 0) return a;
    return gcd(b, a % b);
endfunction

initial begin
    state <= 0; // IDLE
    done <=0;
    result <=0;
    arr <= 8'b0;
    count_ones <=0;
    total_gcd <=0;
    min_len <=0;
    current_index <=0;
end

always_ff @(posedge clk) begin
    if (!rst_n) begin
        state <=0;
        done <=0;
        result <=0;
        arr <=8'b0;
        count_ones <=0;
        total_gcd <=0;
        min_len <=0;
        current_index <=0;
    end else begin
        case (state)
            0: begin // IDLE
                if (start ==1) state <=1; // LOAD
            end
            1: begin // LOAD
                arr <= {a_0, a_1, a_2, a_3, a_4, a_5, a_6, a_7};
                current_index <=1;
                state <=2; // CHECK_ONES
            end
            2: begin // CHECK_ONES
                count_ones <= (arr[0]==1 ? 1 :0) + (arr[1]==1 ? 1 :0) + (arr[2]==1 ? 1 :0) + (arr[3]==1 ? 1 :0) + (arr[4]==1 ? 1 :0) + (arr[5]==1 ? 1 :0) + (arr[6]==1 ? 1 :0) + (arr[7]==1 ? 1 :0);
                state <=3; // CHECK_TOTAL_GCD
            end
            3: begin // CHECK_TOTAL_GCD
                if (current_index <8) begin
                    total_gcd <= gcd(total_gcd, arr[current_index]);
                    current_index <= current_index +1;
                    if (current_index ==8) begin
                        if (total_gcd !=1) begin
                            result <=8'd255;
                            done <=1;
                            state <=6; // DONE
                        end else if (count_ones >0) begin
                            result <=8 - count_ones;
                            done <=1;
                            state <=6;
                        end else begin
                            state <=4; // FIND_SHORTEST
                        end
                    end
                end
            end
            4: begin // FIND_SHORTEST
                min_len <=8;
                if (gcd(arr[0], arr[1]) ==1) min_len <=2;
                if (gcd(arr[1], arr[2]) ==1) min_len <=2;
                if (gcd(arr[2], arr[3]) ==1) min_len <=2;
                if (gcd(arr[3], arr[4]) ==1) min_len <=2;
                if (gcd(arr[4], arr[5]) ==1) min_len <=2;
                if (gcd(arr[5], arr[6]) ==1) min_len <=2;
                if (gcd(arr[6], arr[7]) ==1) min_len <=2;
                if (min_len ==2) begin
                    state <=5; // CALC_RESULT
                end else begin
                    min_len <=3;
                    state <=5;
                end
            end
            5: begin // CALC_RESULT
                if (total_gcd !=1) begin
                    result <=8'd255;
                end else if (count_ones >0) begin
                    result <=8 - count_ones;
                end else begin
                    result <= (min_len -1) +7; // since N=8, operations = (L-1) +7
                end
                done <=1;
                state <=6;
            end
            6: begin // DONE
                if (start ==1) begin // Allow restart
                    state <=0;
                end
            end
        endcase
    end
end
endmodule