module gcd_split (
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [7:0] arr_0,
    input wire [7:0] arr_1,
    input wire [7:0] arr_2,
    input wire [7:0] arr_3,
    input wire [7:0] arr_4,
    input wire [7:0] arr_5,
    input wire [7:0] arr_6,
    input wire [7:0] arr_7,
    output reg done,
    output reg result,
    output reg [7:0] assignment
);

// State machine states
localparam [1:0] IDLE = 2'd0;
localparam [1:0] COMPUTE = 2'd1;
localparam [1:0] CHECK = 2'd2;
localparam [1:0] FINISHED = 2'd3;

reg [1:0] state;
reg [7:0] mask;
reg [7:0] gcd1, gcd2;
reg [7:0] count1, count2;
reg [7:0] arr_reg [0:7];

// GCD function for two numbers
function automatic [7:0] gcd2;
    input [7:0] a, b;
    begin
        if (b == 0) gcd2 = a;
        else gcd2 = gcd2(b, a % b);
    end
endfunction

// Sequential logic
always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        state <= IDLE;
        done <= 1'b0;
        result <= 1'b0;
        assignment <= 8'd0;
        mask <= 8'd0;
        gcd1 <= 8'd0;
        gcd2 <= 8'd0;
        count1 <= 8'd0;
        count2 <= 8'd0;
        // Initialize array registers
        for (integer i = 0; i < 8; i = i + 1) begin
            arr_reg[i] <= 8'd0;
        end
    end else begin
        case (state)
            IDLE: begin
                done <= 1'b0;
                if (start) begin
                    // Capture inputs
                    arr_reg[0] <= arr_0;
                    arr_reg[1] <= arr_1;
                    arr_reg[2] <= arr_2;
                    arr_reg[3] <= arr_3;
                    arr_reg[4] <= arr_4;
                    arr_reg[5] <= arr_5;
                    arr_reg[6] <= arr_6;
                    arr_reg[7] <= arr_7;
                    mask <= 8'b00000001;
                    state <= COMPUTE;
                end
            end
            
            COMPUTE: begin
                // Compute GCD for group 1
                gcd1 <= 8'd0;
                count1 <= 8'd0;
                for (integer i = 0; i < 8; i = i + 1) begin
                    if (mask[i]) begin
                        if (gcd1 == 0) gcd1 <= arr_reg[i];
                        else gcd1 <= gcd2(gcd1, arr_reg[i]);
                        count1 <= count1 + 8'd1;
                    end
                end
                
                // Compute GCD for group 2
                gcd2 <= 8'd0;
                count2 <= 8'd0;
                for (integer i = 0; i < 8; i = i + 1) begin
                    if (~mask[i]) begin
                        if (gcd2 == 0) gcd2 <= arr_reg[i];
                        else gcd2 <= gcd2(gcd2, arr_reg[i]);
                        count2 <= count2 + 8'd1;
                    end
                end
                
                state <= CHECK;
            end
            
            CHECK: begin
                // Check if this split is valid
                if (count1 > 0 && count2 > 0 && gcd1 == 1 && gcd2 == 1) begin
                    result <= 1'b1;
                    assignment <= mask;
                    done <= 1'b1;
                    state <= FINISHED;
                end else begin
                    // Try next mask
                    if (mask == 8'b11111110) begin
                        // All possibilities tried
                        result <= 1'b0;
                        assignment <= 8'd0;
                        done <= 1'b1;
                        state <= FINISHED;
                    end else begin
                        // Increment mask to next valid split
                        if (mask == 8'b00000000) 
                            mask <= 8'b00000001;
                        else if (mask == 8'b11111111)
                            mask <= 8'b00000001;
                        else
                            mask <= mask + 8'd1;
                        state <= COMPUTE;
                    end
                end
            end
            
            FINISHED: begin
                // Wait for reset or new start
                if (!start) begin
                    done <= 1'b0;
                end
            end
            
            default: state <= IDLE;
        endcase
    end
end

endmodule