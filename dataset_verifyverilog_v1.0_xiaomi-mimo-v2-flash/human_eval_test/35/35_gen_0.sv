module MaxFinder (
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [7:0] arr [0:7],
    output reg [7:0] result,
    output reg done
);

    // State definitions
    localparam [1:0] IDLE = 2'd0;
    localparam [1:0] COMPUTE = 2'd1;
    localparam [1:0] FINISH = 2'd2;

    // Internal registers
    reg [1:0] state;
    reg [1:0] next_state;
    reg [7:0] max_result;
    reg [7:0] next_result;
    reg done_internal;
    reg next_done;

    // Comparator tree intermediate results (combinatorial)
    reg [7:0] cmp_1 [0:3];
    reg [7:0] cmp_2 [0:1];
    reg [7:0] cmp_3;

    // State transition logic
    always @(*) begin
        next_state = state;
        next_result = max_result;
        next_done = 1'b0;
        
        case (state)
            IDLE: begin
                next_done = 1'b0;
                if (start) begin
                    next_state = COMPUTE;
                end
            end
            
            COMPUTE: begin
                // Comparator tree: 8 -> 4 -> 2 -> 1
                // Level 1: Compare pairs (0vs1, 2vs3, 4vs5, 6vs7)
                cmp_1[0] = (arr[0] > arr[1]) ? arr[0] : arr[1];
                cmp_1[1] = (arr[2] > arr[3]) ? arr[2] : arr[3];
                cmp_1[2] = (arr[4] > arr[5]) ? arr[4] : arr[5];
                cmp_1[3] = (arr[6] > arr[7]) ? arr[6] : arr[7];
                
                // Level 2: Compare pairs of level 1 results
                cmp_2[0] = (cmp_1[0] > cmp_1[1]) ? cmp_1[0] : cmp_1[1];
                cmp_2[1] = (cmp_1[2] > cmp_1[3]) ? cmp_1[2] : cmp_1[3];
                
                // Level 3: Compare final pair
                cmp_3 = (cmp_2[0] > cmp_2[1]) ? cmp_2[0] : cmp_2[1];
                
                next_result = cmp_3;
                next_done = 1'b1;
                next_state = FINISH;
            end
            
            FINISH: begin
                next_done = 1'b0;
                next_state = IDLE;
            end
            
            default: begin
                next_state = IDLE;
                next_result = 8'd0;
                next_done = 1'b0;
            end
        endcase
    end

    // Sequential logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            result <= 8'd0;
            done <= 1'b0;
            max_result <= 8'd0;
            done_internal <= 1'b0;
            cmp_1[0] <= 8'd0;
            cmp_1[1] <= 8'd0;
            cmp_1[2] <= 8'd0;
            cmp_1[3] <= 8'd0;
            cmp_2[0] <= 8'd0;
            cmp_2[1] <= 8'd0;
            cmp_3 <= 8'd0;
        end else begin
            state <= next_state;
            result <= next_result;
            done <= next_done;
            max_result <= next_result;
            done_internal <= next_done;
        end
    end

endmodule