module mis_finder (
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [3:0] n,
    input wire [4:0] m,
    input wire [191:0] edges_packed,
    output reg [3:0] result,
    output reg done
);

    localparam [1:0] IDLE = 2'd0;
    localparam [1:0] CHECK = 2'd1;
    localparam [1:0] UPDATE = 2'd2;
    localparam [1:0] NEXT = 2'd3;
    localparam [1:0] DONE = 2'd4;
    
    reg [1:0] state;
    reg [7:0] subset;
    reg [3:0] max_size;
    
    wire [7:0] edges [0:23];
    genvar i;
    generate
        for (i = 0; i < 24; i = i + 1) begin : unpack
            assign edges[i] = edges_packed[i*8 +: 8];
        end
    endgenerate

    wire [7:0] max_subset;
    always @(*) begin
        case (n)
            4'd1: max_subset = 8'b00000001;
            4'd2: max_subset = 8'b00000011;
            4'd3: max_subset = 8'b00000111;
            4'd4: max_subset = 8'b00001111;
            4'd5: max_subset = 8'b00011111;
            4'd6: max_subset = 8'b00111111;
            4'd7: max_subset = 8'b01111111;
            4'd8: max_subset = 8'b11111111;
            default: max_subset = 8'b11111111;
        endcase
    end

    wire [23:0] edge_valid_flags;
    generate
        for (i = 0; i < 24; i = i + 1) begin : edge_check
            assign edge_valid_flags[i] = (i < m) ? ~(subset[edges[i][7:4]] & subset[edges[i][3:0]]) : 1'b1;
        end
    endgenerate
    wire is_valid = &edge_valid_flags;

    wire [3:0] size = subset[0] + subset[1] + subset[2] + subset[3] + subset[4] + subset[5] + subset[6] + subset[7];

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            subset <= 8'b0;
            max_size <= 4'b0;
            result <= 4'b0;
            done <= 1'b0;
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    if (start) begin
                        subset <= 8'b0;
                        max_size <= 4'b0;
                        state <= CHECK;
                    end
                end
                CHECK: state <= UPDATE;
                UPDATE: begin
                    if (is_valid && size > max_size)
                        max_size <= size;
                    state <= NEXT;
                end
                NEXT: begin
                    if (subset < max_subset) begin
                        subset <= subset + 1;
                        state <= CHECK;
                    end else begin
                        result <= max_size;
                        done <= 1'b1;
                        state <= DONE;
                    end
                end
                DONE: begin
                    
                end
                default: state <= IDLE;
            endcase
        end
    end
endmodule