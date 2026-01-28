module mis_finder (
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [3:0] n,          // vertices 1-8
    input wire [4:0] m,          // edges 0-24
    input wire [191:0] edges_packed, // 24 edges × 8 bits: {u[3:0], v[3:0]}
    output reg [3:0] result,
    output reg done
);

    // Unpack edges: 24 entries of 8 bits each
    wire [7:0] edges [0:23];
    genvar i;
    generate
        for (i = 0; i < 24; i = i + 1) begin : unpack
            assign edges[i] = edges_packed[i*8 +: 8];
        end
    endgenerate

    // State machine states
    localparam [2:0] IDLE    = 3'd0;
    localparam [2:0] CHECK   = 3'd1;
    localparam [2:0] UPDATE  = 3'd2;
    localparam [2:0] NEXT    = 3'd3;
    localparam [2:0] DONE    = 3'd4;
    reg [2:0] state;

    // Internal registers
    reg [7:0] subset;
    reg [3:0] max_size;
    reg [7:0] max_subset;
    reg [3:0] size;
    reg [23:0] edge_valid_flags;
    reg is_valid;
    integer j;

    // State machine
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            subset <= 8'd0;
            max_size <= 4'd0;
            max_subset <= 8'd255;
            result <= 4'd0;
            done <= 1'b0;
            size <= 4'd0;
            edge_valid_flags <= 24'd0;
            is_valid <= 1'b0;
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    if (start) begin
                        subset <= 8'd0;
                        max_size <= 4'd0;
                        state <= CHECK;
                    end
                end

                CHECK: begin
                    // Calculate size of current subset
                    size <= subset[0] + subset[1] + subset[2] + subset[3] +
                            subset[4] + subset[5] + subset[6] + subset[7];
                    
                    // Initialize edge_valid_flags
                    edge_valid_flags <= 24'hFFFFFF;
                    is_valid <= 1'b1;
                    
                    // Check all edges (sequential to avoid array issues)
                    if (m > 0 && edges[0][7:4] != 4'd0 && edges[0][3:0] != 4'd0) begin
                        edge_valid_flags[0] <= ~(subset[edges[0][7:4]] & subset[edges[0][3:0]]);
                        if (subset[edges[0][7:4]] & subset[edges[0][3:0]]) begin
                            is_valid <= 1'b0;
                        end
                    end
                    
                    state <= UPDATE;
                end

                UPDATE: begin
                    // Continue checking edges (sequential)
                    if (m > 1 && edges[1][7:4] != 4'd0 && edges[1][3:0] != 4'd0) begin
                        edge_valid_flags[1] <= ~(subset[edges[1][7:4]] & subset[edges[1][3:0]]);
                        if (subset[edges[1][7:4]] & subset[edges[1][3:0]]) begin
                            is_valid <= 1'b0;
                        end
                    end
                    if (m > 2 && edges[2][7:4] != 4'd0 && edges[2][3:0] != 4'd0) begin
                        edge_valid_flags[2] <= ~(subset[edges[2][7:4]] & subset[edges[2][3:0]]);
                        if (subset[edges[2][7:4]] & subset[edges[2][3:0]]) begin
                            is_valid <= 1'b0;
                        end
                    end
                    // ... continue for remaining edges if needed
                    
                    state <= NEXT;
                end

                NEXT: begin
                    // Check if current subset is valid and larger than max
                    if (is_valid && size > max_size) begin
                        max_size <= size;
                    end
                    
                    // Calculate max subset based on n
                    case (n)
                        4'd1: max_subset <= 8'b00000001;
                        4'd2: max_subset <= 8'b00000011;
                        4'd3: max_subset <= 8'b00000111;
                        4'd4: max_subset <= 8'b00001111;
                        4'd5: max_subset <= 8'b00011111;
                        4'd6: max_subset <= 8'b00111111;
                        4'd7: max_subset <= 8'b01111111;
                        4'd8: max_subset <= 8'b11111111;
                        default: max_subset <= 8'b11111111;
                    endcase
                    
                    // Move to next subset
                    if (subset < max_subset) begin
                        subset <= subset + 8'd1;
                        state <= CHECK;
                    end else begin
                        result <= max_size;
                        done <= 1'b1;
                        state <= DONE;
                    end
                end

                DONE: begin
                    // Holds result until reset
                end

                default: state <= IDLE;
            endcase
        end
    end
endmodule