//
//  BannerView.swift
//  BilibiliLive
//
//  Created by iManTie on 10/11/25.
//

import SwiftUI

enum FocusItem {
    case leftButton
    case rightButton
    case focusGuide
    case leftGuide
}

struct BannerView: View {
    @StateObject private var viewModel = BannerViewModel()
    @State private var scrollPosition: Int = 0
    @State private var lastChangeTime = Date()
    @FocusState var focusedItem: FocusItem? // 当前焦点对象
    @State private var currentFocusedItem: FocusItem? // 当前焦点对象
    @State private var offsetY: CGFloat = 0
    @State private var currentIndex = 0

    var focusedBannerButton: (() -> Void)?
    var overMoveLeft: (() -> Void)?
    var playAction: ((_ data: FavData) -> Void)?
    var detailAction: ((_ data: FavData) -> Void)?

    var body: some View {
        ZStack(alignment: .bottomLeading) {
            ScrollViewReader { proxy in
                ScrollView(.horizontal, showsIndicators: false) {
                    // 例如显示加载数据
                    LazyHStack(spacing: 0) {
                        ForEach(viewModel.favdatas, id: \.id) { item in
                            ZStack {
                                ItemPhoto(Photo(item.cover)).containerRelativeFrame(.horizontal)
                                    .scrollTransition(axis: .horizontal) { content, phase in
                                        content
                                            .offset(x: phase.isIdentity ? 0 : phase.value * -500)
                                    }
//                                Image("cover")
                            }
                            .containerRelativeFrame(.horizontal)
                            .clipShape(RoundedRectangle(cornerRadius: 1))
                            .id(viewModel.favdatas.firstIndex(of: item))
                        }
                    }
                    //                .containerRelativeFrame(.horizontal)
                }
                .frame(width: 1920)
                .scrollTargetBehavior(.paging)
                .onChange(of: currentIndex) { _, newValue in
                    scrollPosition = newValue
                    withAnimation(.spring(response: 0.6, dampingFraction: 0.8)) {
                        proxy.scrollTo(newValue, anchor: .center)
                    }
                }
            }

            // 底部渐变遮罩
            LinearGradient(
                colors: [.black.opacity(0.8), .clear],
                startPoint: .bottom,
                endPoint: .top
            )
            .ignoresSafeArea()

            // 昨天用于转移焦点的button
            Button {
                print("点击了1")
            } label: {
                Image(systemName: "info.circle")
                    .frame(maxHeight: .infinity)
            }
            .focused($focusedItem, equals: .leftGuide) // 与 @FocusState 绑定
            .opacity(0)
            .padding(.leading, 500)
            .padding(.bottom, 450)

            // 信息页面
            VStack(alignment: .leading, spacing: 12) {
                Text(viewModel.selectData?.title ?? "")
                    .font(.system(size: 55, weight: .bold, design: .default))
                    .animation(.spring(response: 0.6, dampingFraction: 0.75), value: focusedItem)
                    .frame(maxWidth: 650, maxHeight: 140, alignment: .leading)
                    .fixedSize(horizontal: false, vertical: true)

                HStack(spacing: 12) {
                    AsyncImage(url: URL(string: viewModel.selectData?.upper.face ?? "")) { image in
                        image
                            .resizable()
                            .frame(width: 34, height: 34)
                            .cornerRadius(17)
                            .scaledToFill()
                            .clipped()
                    } placeholder: {
//                            ProgressView()
//                                .background(Color.black)
                    }

                    Text(viewModel.selectData?.upper.name ?? "")
                }
                if let intro = viewModel.selectData?.intro {
                    Text(intro)
                        .font(.caption)
                        .frame(maxWidth: 550, maxHeight: 200, alignment: .leading)
                        .foregroundStyle(.gray)
                        .fixedSize(horizontal: false, vertical: true)
                }

                HStack(spacing: 22) {
                    if #available(tvOS 26.0, *) {
                        Button(action: {
                            if let data = viewModel.selectData {
                                playAction?(data)
                                offsetY = 0
                            }
                        }) {
                            Label("播放", systemImage: "play.fill")
                                .padding(.horizontal, 33)
                        }
                        .glassEffect()
                        .focused($focusedItem, equals: .leftButton) // 与 @FocusState 绑定

                        Button {
                            if let data = viewModel.selectData {
                                detailAction?(data)
                                offsetY = 0
                            }

                        } label: {
                            Image(systemName: "info.circle")
                        }
                        .glassEffect()
                        .focused($focusedItem, equals: .rightButton) // 与 @FocusState 绑定

                        Image(systemName: "chevron.right")
                            .symbolEffect(.breathe)
                    } else {
                        Button(action: {
                            if let data = viewModel.selectData {
                                playAction?(data)
                                offsetY = 0
                            }
                        }) {
                            Label("播放", systemImage: "play.fill")
                                .padding(.horizontal, 33)
                        }
                        .focused($focusedItem, equals: .leftButton) // 与 @FocusState 绑定

                        Button {
                            if let data = viewModel.selectData {
                                detailAction?(data)
                                offsetY = 0
                            }

                        } label: {
                            Image(systemName: "info.circle")
                        }
                        .focused($focusedItem, equals: .rightButton) // 与 @FocusState 绑定

                        Image(systemName: "chevron.right")
                            .symbolEffect(.breathe)
                    } // 默认焦点
                }
                
                Button {
                    print("点击了1")
                } label: {
                    Image(systemName: "info.circle")
                        .frame(maxWidth: .infinity)
                }
                .focused($focusedItem, equals: .focusGuide) // 与 @FocusState 绑定
                .opacity(0)
                .padding(.leading, 400)
                .onChange(of: focusedItem) { old, new in

                    print("focusedItem \(old)--\(new)")
                    focusedBannerButton?()
                    if focusedItem == .focusGuide
                        || focusedItem == .leftGuide {
                        focusedItem = .leftButton
                    }

                    // 控制空间偏移
                    if new == nil {
                        // 焦点从控件丢失
                        offsetY = 100
                    } else {
                        offsetY = 0
                    }
                }
            }
            .padding(.leading, 98)
            .padding(.bottom, 137)
            .offset(y: offsetY)
            .animation(.spring(response: 0.7, dampingFraction: 0.9), value: offsetY)

        }
        .onAppear {
            Task {
                try await viewModel.loadFavList()
            }
//            viewModel.createDatas()
        }
        .onMoveCommand { direction in
            // 控制封面的左右移动
            switch direction {
            case .left:
                print("向左")
                if currentFocusedItem == .leftButton {
                    withAnimation(.spring(response: 0.6, dampingFraction: 0.9, blendDuration: 0.1)) {
                        // 在这里写你的动画逻辑，比如滚动或改变状态
                        let x = (scrollPosition*1920) - 1920
                        print("向左\(x)")
                        if x >= 0 {
                            let index = Int(x / 1920)
//                            if #available(tvOS 26.0, *) {
//                                scrollPosition = ScrollPosition(x: x, y: scrollPosition.y ?? 0)
//                            } else {
//                                // Fallback on earlier versions
//                               
//                            }
                            viewModel.setIndex(index: index)
                            currentIndex = index
                        } else {
                            overMoveLeft?()
                        }
                    }
                }
            case .right:

                print("向右")
          
                if currentFocusedItem == .rightButton {
                    withAnimation(.spring(response: 0.6, dampingFraction: 0.9, blendDuration: 0.1)) {
                        // 在这里写你的动画逻辑，比如滚动或改变状态
                        let x = CGFloat((scrollPosition*1920)) + 1920
                        print("向右\(x)")
                        if x <= CGFloat(viewModel.favdatas.count - 1) * 1920 {
                            let index = Int(x / 1920)
//                            currentIndex = index
//                            if #available(tvOS 26.0, *) {
//                                scrollPosition = ScrollPosition(x: x, y: scrollPosition.y ?? 0)
//                            } else {
//                                // Fallback on earlier versions
//                                currentIndex = index
//                            }
                            viewModel.setIndex(index: index)
                            currentIndex = index
                        }
                    }
                }

            default: break
            }

            currentFocusedItem = focusedItem
        }
    }
}

struct Photo: Identifiable {
    var title: String

    var id: Int = .random(in: 0 ... 100)

    init(_ title: String) {
        self.title = title
    }
}

struct ItemPhoto: View {
    var photo: Photo

    init(_ photo: Photo) {
        self.photo = photo
    }

    var body: some View {
        AsyncImage(url: URL(string: photo.title)) { image in
            image
                .resizable()
                .scaledToFill()
                .clipped()
        } placeholder: {
            ProgressView()
                .background(Color.black)
        }
        .frame(width: 1920, height: 1080)
//            .ignoresSafeArea()
//            .focusable(true)
    }
}

#Preview {
    BannerView()
}
