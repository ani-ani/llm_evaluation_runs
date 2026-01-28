module array_append (
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [7:0] tuple_arr [0:7],
    input wire [7:0] list_arr [0:7],
    input wire [3:0] tuple_len,
    input wire [3:0] list_len,
    output reg [7:0] result_arr [0:15],
    output reg done
);

    localparam [1:0] IDLE = 2'd0;
    localparam [1:0] COPY_TUPLE = 2'd1;
    localparam [1:0] COPY_LIST = 2'd2;
    localparam [1:0] FINISH = 2'd3;

    reg [1:0] state;
    reg [4:0] idx;
    reg [7:0] cycle_count;
    localparam [7:0] MAX_CYCLES = 8'd20;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            idx <= 5'd0;
            done <= 1'b0;
            cycle_count <= 8'd0;
            
            integer i;
            for (i = 0; i < 16; i = i + 1) begin
                result_arr[i] <= 8'd0;
            end
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    cycle_count <= 8'd0;
                    if (start) begin
                        state <= COPY_TUPLE;
                        idx <= 5'd0;
                    end
                end
                
                COPY_TUPLE: begin
                    cycle_count <= cycle_count + 8'd1;
                    if (idx < tuple_len) begin
                        result_arr[idx] <= tuple_arr[idx];
                        idx <= idx + 5'd1;
                    end
                    
                    if (idx >= tuple_len || cycle_count >= MAX_CYCLES) begin
                        state <= COPY_LIST;
                    end
                end
                
                COPY_LIST: begin
                    cycle_count <= cycle_count + 8'd1;
                    if (idx < tuple_len + list_len) begin
                        result_arr[idx] <= list_arr[idx - tuple_len];
                        idx <= idx + 5'd1;
                    end
                    
                    if (idx >= tuple_len + list_len || cycle_count >= MAX_CYCLES) begin
                        state <= FINISH;
                    end
                end
                
                FINISH: begin
                    done <= 1'b1;
                    state <= IDLE;
                end
                
                default: state <= IDLE;
            endcase
        end
    end

endmodule