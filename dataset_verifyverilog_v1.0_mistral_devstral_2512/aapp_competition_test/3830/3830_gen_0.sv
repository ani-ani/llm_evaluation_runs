module snake_exhibition #(
    parameter MAX_N = 16
) (
    input clk,
    input rst_n,
    input start,
    input [3:0] n,  // actual number of rooms (2-16)
    input [MAX_N*2-1:0] belts_packed,  // packed belts: each belt = 2 bits: 00='-', 01='>', 10='<'
    output reg [4:0] count,  // number of returnable rooms
    output reg done
);

// Internal state
reg [1:0] belts [0:MAX_N-1];  // unpacked belts
reg [3:0] i;  // loop counter
reg has_gt, has_lt;

// State machine
reg [1:0] state;
localparam IDLE = 2'b00;
localparam CHECK_GT_LT = 2'b01;
localparam COUNT_ROOMS = 2'b10;
localparam FINISH = 2'b11;

// Unpack belts (combinational)
genvar g;
generate
    for (g = 0; g < MAX_N; g = g + 1) begin: unpack_belts
        always @(*) begin
            belts[g] = belts_packed[2*g+1:2*g];
        end
    end
endgenerate

// Main state machine
always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        state <= IDLE;
        done <= 0;
        count <= 0;
        has_gt <= 0;
        has_lt <= 0;
        i <= 0;
    end else begin
        case (state)
            IDLE: begin
                if (start) begin
                    state <= CHECK_GT_LT;
                    has_gt <= 0;
                    has_lt <= 0;
                    i <= 0;
                    done <= 0;
                end
            end
            
            CHECK_GT_LT: begin
                if (i < n) begin
                    if (belts[i] == 2'b01) has_gt <= 1;
                    if (belts[i] == 2'b10) has_lt <= 1;
                    i <= i + 1;
                end else begin
                    i <= 0;
                    count <= 0;
                    state <= COUNT_ROOMS;
                end
            end
            
            COUNT_ROOMS: begin
                if (i < n) begin
                    // Check if room i is returnable
                    if (!has_gt || !has_lt) begin
                        // All rooms are returnable
                        count <= n;
                        state <= FINISH;
                    end else begin
                        // Check adjacent belts
                        if (i == 0) begin
                            if (belts[0] == 2'b00 || belts[n-1] == 2'b00)
                                count <= count + 1;
                        end else begin
                            if (belts[i] == 2'b00 || belts[i-1] == 2'b00)
                                count <= count + 1;
                        end
                        i <= i + 1;
                    end
                end else begin
                    state <= FINISH;
                end
            end
            
            FINISH: begin
                done <= 1;
                state <= IDLE;
            end
            
            default: state <= IDLE;
        endcase
    end
end

endmodule