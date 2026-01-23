module even_odd_count (
    input clk,
    input rst_n, // active low
    input start,
    input signed [31:0] num,
    output reg [4:0] even_count,
    output reg [4:0] odd_count,
    output reg done
);

localparam IDLE = 2'b00;
localparam PROCESSING = 2'b01;
localparam DONE = 2'b10;

reg [31:0] temp_int;
reg [3:0] process_counter;
reg [2:0] state;

always @(posedge clk) begin
    if (!rst_n) begin
        even_count <=0;
        odd_count <=0;
        done <=0;
        temp_int <=0;
        process_counter <=0;
        state <= IDLE;
    end else begin
        if (state == IDLE) begin
            if (start) begin
                temp_int <= (num < 0) ? -num : num;
                if (temp_int ==0) begin
                    even_count <=1;
                    odd_count <=0;
                end else begin
                    even_count <=0;
                    odd_count <=0;
                end
                process_counter <=0;
                state <= PROCESSING;
            end
        end else if (state == PROCESSING) begin
            process_counter <= process_counter +1;
            if (temp_int !=0) begin
                integer digit;
                digit = temp_int %10;
                if (digit %2 ==0) begin
                    even_count <= even_count +1;
                end else begin
                    odd_count <= odd_count +1;
                end
                temp_int <= temp_int /10;
            end
            if (process_counter ==9) begin
                state <= DONE;
            end
        end else if (state == DONE) begin
            done <=1;
        end
    end
end