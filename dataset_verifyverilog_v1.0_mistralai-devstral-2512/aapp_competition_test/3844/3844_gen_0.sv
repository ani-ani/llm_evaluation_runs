module card_game(
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [16:0] card_in,
    input wire card_valid,
    input wire card_done,
    output reg result,
    output reg done
);

    // State declarations
    localparam [2:0] IDLE    = 3'd0;
    localparam [2:0] COLLECT = 3'd1;
    localparam [2:0] SCAN    = 3'd2;
    localparam [2:0] DONE_STATE = 3'd3;
    
    reg [2:0] state;
    reg [16:0] address;
    reg [131071:0] parity;
    reg [16:0] scan_index;
    reg found_odd;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            address <= 17'd0;
            scan_index <= 17'd0;
            found_odd <= 1'b0;
            result <= 1'b0;
            done <= 1'b0;
            // Initialize parity array to 0
            integer i;
            for (i = 0; i < 131072; i = i + 1) begin
                parity[i] <= 1'b0;
            end
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    if (start) begin
                        state <= COLLECT;
                        address <= 17'd0;
                        scan_index <= 17'd0;
                        found_odd <= 1'b0;
                        result <= 1'b0;
                    end
                end

                COLLECT: begin
                    if (card_valid) begin
                        parity[card_in] <= !parity[card_in];
                    end
                    if (card_done) begin
                        state <= SCAN;
                        scan_index <= 17'd0;
                    end
                end

                SCAN: begin
                    if (!found_odd && scan_index < 17'd131072) begin
                        if (parity[scan_index]) begin
                            found_odd <= 1'b1;
                            result <= 1'b1;
                        end
                        scan_index <= scan_index + 17'd1;
                    end
                    if (found_odd || scan_index == 17'd131072) begin
                        state <= DONE_STATE;
                    end
                end

                DONE_STATE: begin
                    done <= 1'b1;
                    state <= IDLE;
                end

                default: state <= IDLE;
            endcase
        end
    end
endmodule