module median_calculator (
    input clk,
    input rst_n,
    input [3:0] n,
    input [7:0][15:0] data,
    input start_trig,
    output [15:0] result,
    output reg done
);

reg [15:0] arr [0:7];
reg [2:0] state;  // 0-7 for sorting, 8 for done state
reg [15:0] median;
reg [15:0] new_arr [0:7];
integer i;

always_comb begin
    new_arr = arr;
    for (i = 0; i < 7; i++) begin
        if (i + 1 < n) begin
            if (arr[i] > arr[i+1]) begin
                new_arr[i] = arr[i+1];
                new_arr[i+1] = arr[i];
            end
        end
    end
end

always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        arr[0] <= 0;
        arr[1] <= 0;
        arr[2] <= 0;
        arr[3] <= 0;
        arr[4] <= 0;
        arr[5] <= 0;
        arr[6] <= 0;
        arr[7] <= 0;
        state <= 0;
        done <= 0;
        median <= 0;
    end
    else if (start_trig) begin
        arr[0] <= data[0];
        arr[1] <= data[1];
        arr[2] <= data[2];
        arr[3] <= data[3];
        arr[4] <= data[4];
        arr[5] <= data[5];
        arr[6] <= data[6];
        arr[7] <= data[7];
        state <= 0;
        done <= 0;
    end
    else if (state < 7) begin
        arr <= new_arr;
        state <= state + 1;
        done <= 0;
    end
    else if (state == 7) begin
        arr <= new_arr;
        state <= 8;
        done <= 1;
        
        if (n[0]) begin  // odd n
            median <= new_arr[n >> 1];
        end
        else begin  // even n
            reg signed [16:0] total;
            total = $signed(new_arr[(n >> 1) - 1]) + $signed(new_arr[n >> 1]);
            
            if (total >= 0) begin
                if (total[0]) 
                    median <= (total + 1) >> 1;
                else
                    median <= total >> 1;
            end
            else begin
                if (total[0]) 
                    median <= (total - 1) >> 1;
                else
                    median <= total >> 1;
            end
        end
    end
    // state 8: stay in done state until next start_trig
end

assign result = median;

endmodule