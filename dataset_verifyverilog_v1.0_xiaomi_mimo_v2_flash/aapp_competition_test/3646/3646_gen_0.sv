module frog_jumps #(
    parameter N = 8,
    parameter SPOT_WIDTH = 8,
    parameter IDX_WIDTH = 4
)(
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [N*SPOT_WIDTH-1:0] spots_flat,
    output reg [IDX_WIDTH-1:0] max_index,
    output reg done
);
    // Unpack spots into an array for easy indexing
    wire [SPOT_WIDTH-1:0] spots [0:N-1];
    generate
        genvar g;
        for (g=0; g<N; g=g+1) begin
            assign spots[g] = spots_flat[g*SPOT_WIDTH +: SPOT_WIDTH];
        end
    endgenerate

    // Reachable flags
    reg [N-1:0] reachable;

    // State machine states
    localparam [1:0] IDLE = 2'b00;
    localparam [1:0] LOOP = 2'b01;
    localparam [1:0] DONE = 2'b10;
    reg [1:0] state;

    // Index counters
    reg [IDX_WIDTH-1:0] i, j;

    // Condition computation
    wire [SPOT_WIDTH:0] sum = spots[i] + spots[j];
    wire [IDX_WIDTH:0] diff = j - i;          // unsigned, width = IDX_WIDTH+1
    wire condition_met = reachable[i] && (sum == diff);

    // Main sequential logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            reachable <= 0;
            max_index <= 0;
            i <= 0;
            j <= 0;
            done <= 0;
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    if (start) begin
                        // Initialize: only pebble 0 is reachable
                        reachable <= 0;
                        reachable[0] <= 1;
                        max_index <= 0;
                        i <= 0;
                        j <= 1;              // start with pair (0,1)
                        state <= LOOP;
                    end
                end

                LOOP: begin
                    if (i >= N-1) begin
                        // No more pairs to check
                        state <= DONE;
                        done <= 1;
                    end else if (j >= N) begin
                        // Move to next i, reset j to i+1
                        i <= i + 1;
                        j <= i + 2;          // new i will be i+1, so j = (i+1)+1 = i+2
                    end else begin
                        // Check jump condition for current (i,j)
                        if (condition_met) begin
                            if (!reachable[j]) begin
                                reachable[j] <= 1;
                                if (j > max_index) begin
                                    max_index <= j;
                                end
                            end
                        end
                        j <= j + 1;
                    end
                end

                DONE: begin
                    // Stay in DONE until reset
                end

                default: state <= IDLE;
            endcase
        end
    end
endmodule